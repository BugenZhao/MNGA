//! Converts the legacy NGA `read.php` HTML payload into the XML “package” format
//! that the rest of the topic pipeline expects. This stays lenient so that small
//! markup shifts on the NGA side do not crash `get_topic_details`.

use crate::error::{ServiceError, ServiceResult};
use lazy_static::lazy_static;
use protos::DataModel::ErrorMessage;
use quick_xml::Writer;
use quick_xml::events::{BytesEnd, BytesStart, BytesText, Event};
use regex::Regex;
use scraper::{ElementRef, Html, Selector};
use serde_json::Value;
use std::collections::HashMap;
use sxd_document::{Package, parser};

const POST_PROC_MARKER: &str = "commonui.postArg.proc(";
const USER_INFO_MARKER: &str = "commonui.userInfo.setAll(";
const ALERT_MARKER: &str = "commonui.loadAlertInfo(";
const PAGE_MARKER: &str = "var __PAGE";
const MIN_POST_ARGS: usize = 23;
// NGA wraps error pages inside these HTML comments; keep the markers explicit so
// we can surface the original error message rather than attempting to parse the
// bogus HTML as a topic page.
const ERROR_CODE_START: &str = "<!--msgcodestart-->";
const ERROR_CODE_END: &str = "<!--msgcodeend-->";
const ERROR_INFO_START: &str = "<!--msginfostart-->";
const ERROR_INFO_END: &str = "<!--msginfoend-->";

/// Thread-level identifiers extracted from the inline bootstrap script.
#[derive(Clone, Debug, Default)]
struct CurrentVars {
    /// Forum id extracted from the inline JS block.
    fid: String,
    /// Topic id extracted from the inline JS block.
    tid: String,
    /// Server-side page size hint; used to derive `__R__ROWS_PAGE`.
    page_posts: u32,
}

/// Metadata emitted by `commonui.postArg.proc` for each floor.
#[derive(Clone, Debug)]
struct PostArgs {
    pid: String,
    post_type: String,
    author_id: String,
    timestamp: u64,
    score: i32,
    score_2: i32,
    recommend: i32,
    content_length: u32,
    from_client: String,
    follow: i32,
}

/// Flattened reply data that becomes `<item>` nodes under `__R`.
#[derive(Clone, Debug, Default)]
struct PostEntry {
    floor: u32,
    pid: String,
    tid: String,
    fid: String,
    author_id: String,
    subject: String,
    content: String,
    post_date_display: String,
    timestamp: u64,
    score: i32,
    score_2: i32,
    recommend: i32,
    content_length: u32,
    from_client: String,
    follow: i32,
    post_type: String,
    alter_info: String,
}

/// Collapsed topic summary that populates `__T` in the synthetic XML.
#[derive(Clone, Debug, Default)]
struct TopicMeta {
    fid: String,
    tid: String,
    subject: String,
    author_id: String,
    author_name: String,
    post_timestamp: u64,
    last_post_timestamp: u64,
    replies: u32,
}

/// Pagination hints derived from the `__PAGE` JS struct.
#[derive(Clone, Copy, Debug, Default)]
struct PageMeta {
    total_pages: u32,
    per_page: u32,
}

/// Ready-to-serialize user entries for the `__U` section.
#[derive(Clone, Debug, Default)]
struct UserEntry {
    fields: Vec<(String, String)>,
}

/// Parsed user roster plus a uid -> username map for later lookups.
#[derive(Clone, Debug, Default)]
struct ParsedUsers {
    entries: Vec<UserEntry>,
    names: HashMap<String, String>,
}

/// Converts `quick_xml` errors into `ServiceError`s with a stable message.
#[inline]
fn map_xml_err(err: quick_xml::Error) -> ServiceError {
    ServiceError::MngaInternal(format!("XML serialization failed: {err}"))
}

/// Entry point that turns `read.php` HTML into the XML package consumed by the
/// rest of the topic pipeline.
pub fn build_topic_package(raw_html: &str) -> ServiceResult<Package> {
    if let Some(err) = detect_nga_error(raw_html) {
        return Err(err);
    }
    let document = Html::parse_document(raw_html);
    let vars = parse_current_vars(raw_html)?;
    let post_args = parse_post_args(raw_html);
    if post_args.is_empty() {
        return Err(ServiceError::MngaInternal(
            "Unable to locate post metadata in read.php payload".to_owned(),
        ));
    }
    let alerts = parse_alerts(raw_html);
    let ParsedUsers {
        entries: users,
        names,
    } = parse_user_info(raw_html)?;
    let posts = extract_posts(&document, &vars, &post_args, &alerts)?;
    if posts.is_empty() {
        return Err(ServiceError::MngaInternal(
            "No posts were extracted from the read.php document".to_owned(),
        ));
    }
    let page_meta = parse_page_meta(raw_html);
    let observed_posts = posts.len() as u32;
    let rows_total = page_meta.rows(observed_posts);
    let effective_rows = rows_total.max(observed_posts);
    let rows_per_page = page_meta
        .rows_per_page(vars.page_posts.max(observed_posts))
        .max(1);
    let subject = extract_topic_subject(&document, &posts);
    let forum_name = extract_forum_name(&document);
    let topic_meta = build_topic_meta(&vars, &subject, &posts, &names, effective_rows)?;
    let xml = assemble_xml(
        &users,
        &posts,
        &topic_meta,
        &forum_name,
        effective_rows,
        rows_per_page,
    )?;
    let package = parser::parse(&xml)
        .map_err(|e| ServiceError::MngaInternal(format!("Synthetic XML parse failed: {e}")))?;
    Ok(package)
}

/// Extracts NGA's inline error payload and converts it into `ServiceError::Nga`.
fn detect_nga_error(source: &str) -> Option<ServiceError> {
    let code = extract_segment(source, ERROR_CODE_START, ERROR_CODE_END)?
        .trim()
        .to_owned();
    if code.is_empty() {
        return None;
    }

    let info_raw = extract_first_non_empty_segment(source, ERROR_INFO_START, ERROR_INFO_END)?;
    let info = sanitize_error_text(&info_raw);
    if info.is_empty() {
        return None;
    }

    Some(ServiceError::Nga(ErrorMessage {
        code,
        info,
        ..Default::default()
    }))
}

/// Returns the first non-empty substring bounded by the provided markers.
fn extract_first_non_empty_segment(source: &str, start: &str, end: &str) -> Option<String> {
    let mut offset = 0;
    while let Some(rel_start) = source[offset..].find(start) {
        let segment_start = offset + rel_start + start.len();
        let tail = &source[segment_start..];
        if let Some(rel_end) = tail.find(end) {
            let segment = &tail[..rel_end];
            if !segment.trim().is_empty() {
                return Some(segment.trim().to_string());
            }
            offset = segment_start + rel_end + end.len();
        } else {
            break;
        }
    }
    None
}

/// Minimal substring helper that returns the raw text between two sentinels.
fn extract_segment<'a>(source: &'a str, start: &str, end: &str) -> Option<&'a str> {
    let start_idx = source.find(start)? + start.len();
    let tail = &source[start_idx..];
    let end_idx = tail.find(end)?;
    Some(&tail[..end_idx])
}

/// Strips HTML/whitespace noise and decodes entities in NGA error payloads.
fn sanitize_error_text(raw: &str) -> String {
    lazy_static! {
        static ref TAG_RE: Regex = Regex::new(r"<[^>]+>").unwrap();
    }
    let without_tags = TAG_RE.replace_all(raw, " ");
    let unescaped = text::unescape(without_tags.trim());
    collapse_whitespace(&unescaped)
}

/// Collapses consecutive whitespace into single spaces for UI-friendly strings.
fn collapse_whitespace(input: &str) -> String {
    let mut out = String::new();
    let mut seen_space = false;
    for ch in input.chars() {
        if ch.is_whitespace() {
            if !seen_space {
                out.push(' ');
                seen_space = true;
            }
        } else {
            seen_space = false;
            out.push(ch);
        }
    }
    out.trim().to_string()
}

/// Reads the inline `<script>` block to capture thread-level identifiers.
fn parse_current_vars(source: &str) -> ServiceResult<CurrentVars> {
    let fid = capture_assignment(source, "__CURRENT_FID")
        .ok_or_else(|| ServiceError::MngaInternal("Missing __CURRENT_FID".to_owned()))?;
    let tid = capture_assignment(source, "__CURRENT_TID")
        .ok_or_else(|| ServiceError::MngaInternal("Missing __CURRENT_TID".to_owned()))?;
    let page_posts = capture_assignment(source, "__CURRENT_PAGE_POSTS")
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(0);
    Ok(CurrentVars {
        fid,
        tid,
        page_posts,
    })
}

/// Extracts a JS assignment value (`foo = parseInt('123')` or `foo = 456`).
fn capture_assignment(source: &str, key: &str) -> Option<String> {
    let idx = source.find(key)?;
    let remainder = &source[idx + key.len()..];
    let remainder = remainder.trim_start();
    if !remainder.starts_with('=') {
        return None;
    }
    let value = remainder[1..].trim_start();
    if value.starts_with("parseInt") {
        let open = value.find(|c| c == '\'' || c == '"')?;
        let tail = &value[open + 1..];
        let close = tail.find(|c| c == '\'' || c == '"')?;
        return Some(tail[..close].to_string());
    }
    let terminators = [',', ';', '\n'];
    let end = value
        .find(|c| terminators.contains(&c))
        .unwrap_or(value.len());
    Some(
        value[..end]
            .trim_matches(|c| c == '\'' || c == '"')
            .trim()
            .to_string(),
    )
}

/// Parses every `commonui.postArg.proc` call into `PostArgs` keyed by floor.
fn parse_post_args(source: &str) -> HashMap<u32, PostArgs> {
    let mut map = HashMap::new();
    for args_raw in capture_calls(source, POST_PROC_MARKER) {
        let args = split_arguments(&args_raw);
        if args.len() < MIN_POST_ARGS {
            continue;
        }
        if let Ok(floor) = args[0].trim().parse::<u32>() {
            let pid = normalize_literal(&args[10]);
            let post_type = normalize_literal(&args[11]);
            let author_id = normalize_literal(&args[13]);
            let timestamp = normalize_literal(&args[14]).parse::<u64>().unwrap_or(0);
            let (score, score_2, recommend) = parse_scores(&normalize_literal(&args[15]));
            let content_length = normalize_literal(&args[16]).parse::<u32>().unwrap_or(0);
            let from_client = normalize_literal(&args[19]);
            let follow = normalize_literal(&args[22]).parse::<i32>().unwrap_or(0);
            map.insert(
                floor,
                PostArgs {
                    pid,
                    post_type,
                    author_id,
                    timestamp,
                    score,
                    score_2,
                    recommend,
                    content_length,
                    from_client,
                    follow,
                },
            );
        }
    }
    map
}

/// Collects per-floor alert text produced by `commonui.loadAlertInfo`.
fn parse_alerts(source: &str) -> HashMap<u32, String> {
    let mut map = HashMap::new();
    for args_raw in capture_calls(source, ALERT_MARKER) {
        let args = split_arguments(&args_raw);
        if args.len() < 2 {
            continue;
        }
        let message = normalize_literal(&args[0]);
        let target = normalize_literal(&args[1]);
        if let Some(floor) = target
            .strip_prefix("alertc")
            .and_then(|suffix| suffix.parse::<u32>().ok())
        {
            let trimmed = message.trim();
            if !trimmed.is_empty() {
                map.insert(floor, trimmed.to_string());
            }
        }
    }
    map
}

/// Extracts pagination hints from the `__PAGE` JS struct.
fn parse_page_meta(source: &str) -> PageMeta {
    if let Some(pos) = source.find(PAGE_MARKER) {
        let tail = &source[pos..];
        if let Some(start) = tail.find('{') {
            if let Some(end) = tail[start..].find('}') {
                let body = &tail[start + 1..start + end];
                let mut total_pages = None;
                let mut per_page = None;
                for chunk in body.split(',') {
                    let mut parts = chunk.splitn(2, ':');
                    let key = parts.next().map(str::trim);
                    let value = parts.next().map(str::trim);
                    match (key, value) {
                        (Some("1"), Some(v)) if total_pages.is_none() => {
                            total_pages = v.parse::<u32>().ok();
                        }
                        (Some("3"), Some(v)) if per_page.is_none() => {
                            per_page = v.parse::<u32>().ok();
                        }
                        _ => {}
                    }
                }
                return PageMeta {
                    total_pages: total_pages.unwrap_or(1),
                    per_page: per_page.unwrap_or(0),
                };
            }
        }
    }
    PageMeta {
        total_pages: 1,
        per_page: 0,
    }
}

impl PageMeta {
    /// Resolves the total rows count using pagination hints.
    fn rows(&self, observed: u32) -> u32 {
        if self.total_pages <= 1 || self.per_page == 0 {
            observed
        } else {
            self.total_pages.saturating_mul(self.per_page).max(observed)
        }
    }
    /// Resolves the rows-per-page value with a caller-provided fallback.
    fn rows_per_page(&self, fallback: u32) -> u32 {
        if self.per_page == 0 {
            fallback
        } else {
            self.per_page
        }
    }
}

/// Parses the inline user JSON blob into `ParsedUsers`.
fn parse_user_info(source: &str) -> ServiceResult<ParsedUsers> {
    // The embedded JSON is produced by inline JS; strip control chars to keep
    // `serde_json` happy before parsing.
    let mut entries = Vec::new();
    let mut names = HashMap::new();
    if let Some(arg) = capture_calls(source, USER_INFO_MARKER).into_iter().next() {
        let sanitized = arg
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
        let value: Value = serde_json::from_str(&sanitized)
            .map_err(|e| ServiceError::MngaInternal(format!("Invalid embedded user JSON: {e}")))?;
        if let Value::Object(map) = value {
            for (key, entry) in map {
                if key.starts_with("__") {
                    continue;
                }
                if let Value::Object(obj) = entry {
                    let mut fields = Vec::new();
                    let mut has_uid = false;
                    for (field, val) in obj {
                        if let Some(text) = json_value_to_string(&val) {
                            if field == "uid" {
                                has_uid = true;
                            }
                            if field == "username" {
                                names.insert(key.clone(), text.clone());
                            }
                            fields.push((field, text));
                        }
                    }
                    if !has_uid {
                        fields.push(("uid".to_owned(), key.clone()));
                    }
                    entries.push(UserEntry { fields });
                }
            }
        }
    }
    Ok(ParsedUsers { entries, names })
}

/// Converts arbitrary JSON scalars into owned strings for XML emission.
fn json_value_to_string(value: &Value) -> Option<String> {
    match value {
        Value::Null => Some(String::new()),
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        Value::Bool(b) => Some(if *b { "1".to_owned() } else { "0".to_owned() }),
        _ => None,
    }
}

/// Builds `PostEntry` records by aligning DOM nodes with `PostArgs` metadata.
fn extract_posts(
    document: &Html,
    vars: &CurrentVars,
    post_args: &HashMap<u32, PostArgs>,
    alerts: &HashMap<u32, String>,
) -> ServiceResult<Vec<PostEntry>> {
    let row_selector = Selector::parse("tr.postrow").unwrap();
    let floor_selector = Selector::parse("a[name^=\"l\"]").unwrap();
    let mut posts = Vec::new();
    for row in document.select(&row_selector) {
        let floor = row
            .select(&floor_selector)
            .next()
            .and_then(|anchor| anchor.value().attr("name"))
            .and_then(|name| name.strip_prefix('l'))
            .and_then(|value| value.parse::<u32>().ok())
            .ok_or_else(|| {
                ServiceError::MngaInternal("Unable to read floor marker for a post row".to_owned())
            })?;
        let args = post_args.get(&floor).ok_or_else(|| {
            ServiceError::MngaInternal(format!("Missing post metadata for floor {floor}"))
        })?;
        let content_id = format!("postcontent{floor}");
        let subject_id = format!("postsubject{floor}");
        let date_id = format!("postdate{floor}");
        let content = find_descendant_html(row, &content_id);
        let subject = find_descendant_text(row, &subject_id);
        let post_date_display = find_descendant_text(row, &date_id);
        let alter_info = alerts.get(&floor).cloned().unwrap_or_default();
        posts.push(PostEntry {
            floor,
            pid: args.pid.clone(),
            tid: vars.tid.clone(),
            fid: vars.fid.clone(),
            author_id: args.author_id.clone(),
            subject,
            content,
            post_date_display,
            timestamp: args.timestamp,
            score: args.score,
            score_2: args.score_2,
            recommend: args.recommend,
            content_length: args.content_length,
            from_client: args.from_client.clone(),
            follow: args.follow,
            post_type: args.post_type.clone(),
            alter_info,
        });
    }
    posts.sort_by_key(|p| p.floor);
    Ok(posts)
}

/// Pulls plain text from the element identified by `id`.
fn find_descendant_text(node: ElementRef<'_>, id: &str) -> String {
    match Selector::parse(&format!("#{id}")) {
        Ok(selector) => node
            .select(&selector)
            .next()
            .map(|el| el.text().collect::<String>().trim().to_string())
            .unwrap_or_default(),
        Err(_) => String::new(),
    }
}

/// Returns trimmed inner HTML from the targeted element.
fn find_descendant_html(node: ElementRef<'_>, id: &str) -> String {
    match Selector::parse(&format!("#{id}")) {
        Ok(selector) => node
            .select(&selector)
            .next()
            .map(|el| el.inner_html().replace("<br>", "\n").trim().to_string())
            .unwrap_or_default(),
        Err(_) => String::new(),
    }
}

/// Synthesizes the topic summary (`__T`) using floor 0 plus fallbacks.
fn build_topic_meta(
    vars: &CurrentVars,
    subject: &str,
    posts: &[PostEntry],
    names: &HashMap<String, String>,
    rows_total: u32,
) -> ServiceResult<TopicMeta> {
    // NGA omits a dedicated topic summary in HTML mode; synthesize one using
    // the first floor so downstream cache logic still works.
    let first = posts
        .iter()
        .find(|p| p.floor == 0)
        .or_else(|| posts.first())
        .ok_or_else(|| ServiceError::MngaInternal("Missing topic main floor".to_owned()))?;
    let author_name = names
        .get(&first.author_id)
        .cloned()
        .unwrap_or_else(|| first.author_id.clone());
    let last_post_timestamp = posts
        .iter()
        .map(|p| p.timestamp)
        .max()
        .unwrap_or(first.timestamp);
    Ok(TopicMeta {
        fid: vars.fid.clone(),
        tid: vars.tid.clone(),
        subject: if subject.is_empty() {
            first.subject.clone()
        } else {
            subject.to_owned()
        },
        author_id: first.author_id.clone(),
        author_name,
        post_timestamp: first.timestamp,
        last_post_timestamp,
        replies: rows_total.saturating_sub(1),
    })
}

/// Emits the synthetic XML matching NGA's `lite=xml` structure.
fn assemble_xml(
    users: &[UserEntry],
    posts: &[PostEntry],
    topic: &TopicMeta,
    forum_name: &str,
    rows_total: u32,
    rows_per_page: u32,
) -> ServiceResult<String> {
    // Emit the same shape as `lite=xml` so the XPath extractors stay untouched.
    let mut writer = Writer::new(Vec::new());
    writer
        .write_event(Event::Start(BytesStart::new("root")))
        .map_err(map_xml_err)?;
    write_users(&mut writer, users)?;
    write_topic(&mut writer, topic)?;
    write_forum(&mut writer, forum_name)?;
    write_posts(&mut writer, posts)?;
    write_text_element(&mut writer, "__ROWS", &rows_total.to_string())?;
    write_text_element(&mut writer, "__R__ROWS_PAGE", &rows_per_page.to_string())?;
    writer
        .write_event(Event::End(BytesEnd::new("root")))
        .map_err(map_xml_err)?;
    let bytes = writer.into_inner();
    String::from_utf8(bytes)
        .map_err(|e| ServiceError::MngaInternal(format!("Generated XML not UTF-8: {e}")))
}

/// Serializes the `__U` section.
fn write_users(writer: &mut Writer<Vec<u8>>, users: &[UserEntry]) -> Result<(), ServiceError> {
    writer
        .write_event(Event::Start(BytesStart::new("__U")))
        .map_err(map_xml_err)?;
    for user in users {
        writer
            .write_event(Event::Start(BytesStart::new("item")))
            .map_err(map_xml_err)?;
        for (field, value) in &user.fields {
            write_text_element(writer, field, value)?;
        }
        writer
            .write_event(Event::End(BytesEnd::new("item")))
            .map_err(map_xml_err)?;
    }
    writer
        .write_event(Event::End(BytesEnd::new("__U")))
        .map_err(map_xml_err)?;
    Ok(())
}

/// Serializes the `__T` topic summary.
fn write_topic(writer: &mut Writer<Vec<u8>>, topic: &TopicMeta) -> Result<(), ServiceError> {
    writer
        .write_event(Event::Start(BytesStart::new("__T")))
        .map_err(map_xml_err)?;
    write_text_element(writer, "subject", &topic.subject)?;
    write_text_element(writer, "tid", &topic.tid)?;
    write_text_element(writer, "quote_from", &topic.tid)?;
    write_text_element(writer, "fid", &topic.fid)?;
    write_text_element(writer, "author", &topic.author_name)?;
    write_text_element(writer, "authorid", &topic.author_id)?;
    write_text_element(writer, "postdate", &topic.post_timestamp.to_string())?;
    write_text_element(writer, "lastpost", &topic.last_post_timestamp.to_string())?;
    write_text_element(writer, "replies", &topic.replies.to_string())?;
    writer
        .write_event(Event::End(BytesEnd::new("__T")))
        .map_err(map_xml_err)?;
    Ok(())
}

/// Serializes the `__F` wrapper that carries the forum name.
fn write_forum(writer: &mut Writer<Vec<u8>>, name: &str) -> Result<(), ServiceError> {
    writer
        .write_event(Event::Start(BytesStart::new("__F")))
        .map_err(map_xml_err)?;
    write_text_element(writer, "name", name)?;
    writer
        .write_event(Event::End(BytesEnd::new("__F")))
        .map_err(map_xml_err)?;
    Ok(())
}

/// Serializes all `__R/item` records.
fn write_posts(writer: &mut Writer<Vec<u8>>, posts: &[PostEntry]) -> Result<(), ServiceError> {
    writer
        .write_event(Event::Start(BytesStart::new("__R")))
        .map_err(map_xml_err)?;
    for post in posts {
        writer
            .write_event(Event::Start(BytesStart::new("item")))
            .map_err(map_xml_err)?;
        write_text_element(writer, "content", &post.content)?;
        write_text_element(writer, "alterinfo", &post.alter_info)?;
        write_text_element(writer, "tid", &post.tid)?;
        write_text_element(writer, "score", &post.score.to_string())?;
        write_text_element(writer, "score_2", &post.score_2.to_string())?;
        write_text_element(writer, "postdate", &post.post_date_display)?;
        write_text_element(writer, "authorid", &post.author_id)?;
        write_text_element(writer, "subject", &post.subject)?;
        write_text_element(writer, "type", &post.post_type)?;
        write_text_element(writer, "fid", &post.fid)?;
        write_text_element(writer, "pid", &post.pid)?;
        write_text_element(writer, "recommend", &post.recommend.to_string())?;
        write_text_element(writer, "follow", &post.follow.to_string())?;
        write_text_element(writer, "lou", &post.floor.to_string())?;
        write_text_element(writer, "content_length", &post.content_length.to_string())?;
        write_text_element(writer, "from_client", &post.from_client)?;
        write_text_element(writer, "postdatetimestamp", &post.timestamp.to_string())?;
        writer
            .write_event(Event::End(BytesEnd::new("item")))
            .map_err(map_xml_err)?;
    }
    writer
        .write_event(Event::End(BytesEnd::new("__R")))
        .map_err(map_xml_err)?;
    Ok(())
}

/// Helper that emits a `<name>value</name>` pair.
fn write_text_element(
    writer: &mut Writer<Vec<u8>>,
    name: &str,
    value: &str,
) -> Result<(), ServiceError> {
    writer
        .write_event(Event::Start(BytesStart::new(name)))
        .map_err(map_xml_err)?;
    writer
        .write_event(Event::Text(BytesText::new(value)))
        .map_err(map_xml_err)?;
    writer
        .write_event(Event::End(BytesEnd::new(name)))
        .map_err(map_xml_err)?;
    Ok(())
}

/// Collects every argument list for calls that start with the provided marker.
fn capture_calls(source: &str, marker: &str) -> Vec<String> {
    let mut calls = Vec::new();
    let mut offset = 0;
    // Some scripts repeat the same helper call; keep scanning past each closed
    // parenthesis to gather every argument list.
    while let Some(pos) = source[offset..].find(marker) {
        let start = offset + pos + marker.len();
        if let Some((args, consumed)) = capture_parenthesized(&source[start..]) {
            calls.push(args);
            offset = start + consumed;
        } else {
            break;
        }
    }
    calls
}

/// Parses nested parentheses while honoring quoted strings.
fn capture_parenthesized(text: &str) -> Option<(String, usize)> {
    let mut depth = 1;
    let mut in_single = false;
    let mut in_double = false;
    let mut escape = false;
    for (idx, ch) in text.char_indices() {
        if escape {
            escape = false;
            continue;
        }
        match ch {
            '\\' if in_single || in_double => {
                escape = true;
            }
            '\'' if !in_double => {
                in_single = !in_single;
            }
            '"' if !in_single => {
                in_double = !in_double;
            }
            '(' if !in_single && !in_double => {
                depth += 1;
            }
            ')' if !in_single && !in_double => {
                depth -= 1;
                if depth == 0 {
                    return Some((text[..idx].to_string(), idx + 1));
                }
            }
            _ => {}
        }
    }
    None
}

/// Splits a JS argument list while accounting for nested delimiters.
fn split_arguments(args: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut current = String::new();
    let mut depth_round = 0;
    let mut depth_square = 0;
    let mut depth_curly = 0;
    let mut in_single = false;
    let mut in_double = false;
    let mut escape = false;
    for ch in args.chars() {
        if escape {
            current.push(ch);
            escape = false;
            continue;
        }
        match ch {
            '\\' if in_single || in_double => {
                escape = true;
                current.push(ch);
            }
            '\'' if !in_double => {
                in_single = !in_single;
                current.push(ch);
            }
            '"' if !in_single => {
                in_double = !in_double;
                current.push(ch);
            }
            '(' if !in_single && !in_double => {
                depth_round += 1;
                current.push(ch);
            }
            ')' if !in_single && !in_double && depth_round > 0 => {
                depth_round -= 1;
                current.push(ch);
            }
            '[' if !in_single && !in_double => {
                depth_square += 1;
                current.push(ch);
            }
            ']' if !in_single && !in_double && depth_square > 0 => {
                depth_square -= 1;
                current.push(ch);
            }
            '{' if !in_single && !in_double => {
                depth_curly += 1;
                current.push(ch);
            }
            '}' if !in_single && !in_double && depth_curly > 0 => {
                depth_curly -= 1;
                current.push(ch);
            }
            ',' if !in_single
                && !in_double
                && depth_round == 0
                && depth_square == 0
                && depth_curly == 0 =>
            {
                out.push(current.trim().to_string());
                current.clear();
            }
            _ => current.push(ch),
        }
    }
    if !current.trim().is_empty() {
        out.push(current.trim().to_string());
    }
    out
}

/// Removes surrounding quotes/escapes from JS literals.
fn normalize_literal(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.eq_ignore_ascii_case("null") {
        String::new()
    } else if (trimmed.starts_with('\'') && trimmed.ends_with('\''))
        || (trimmed.starts_with('"') && trimmed.ends_with('"'))
    {
        trimmed[1..trimmed.len() - 1]
            .replace("\\'", "'")
            .replace("\\\"", "\"")
    } else {
        trimmed.to_string()
    }
}

/// Parses `score,score2,recommend` triples from comma-separated strings.
fn parse_scores(raw: &str) -> (i32, i32, i32) {
    let mut iter = raw.split(',').filter_map(|s| s.trim().parse::<i32>().ok());
    let score = iter.next().unwrap_or(0);
    let score_2 = iter.next().unwrap_or(0);
    let recommend = iter.next().unwrap_or(0);
    (score, score_2, recommend)
}

/// Resolves the topic subject using the DOM heading or the first post.
fn extract_topic_subject(document: &Html, posts: &[PostEntry]) -> String {
    Selector::parse("#currentTopicName")
        .ok()
        .and_then(|selector| {
            document
                .select(&selector)
                .next()
                .map(|el| el.text().collect::<String>().trim().to_string())
        })
        .filter(|s| !s.is_empty())
        .or_else(|| posts.first().map(|p| p.subject.clone()))
        .unwrap_or_default()
}

/// Extracts the forum name from the DOM header section.
fn extract_forum_name(document: &Html) -> String {
    Selector::parse("#currentForumName")
        .ok()
        .and_then(|selector| {
            document
                .select(&selector)
                .next()
                .map(|el| el.text().collect::<String>().trim().to_string())
        })
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::post::extract_post;
    use crate::utils::{extract_node, extract_nodes};

    #[test]
    fn parses_fixture() -> ServiceResult<()> {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../read.php");
        let html = std::fs::read_to_string(path).expect("read.php fixture");
        let package = build_topic_package(&html)?;
        let topic = extract_node(&package, "/root/__T", super::super::extract_topic)?
            .flatten()
            .expect("topic is present");
        assert_eq!(topic.get_id(), "45150945");
        assert_eq!(topic.get_fid(), "275");
        assert!(topic.get_subject().get_content().contains("测试好多标签"));
        let posts = extract_nodes(&package, "/root/__R/item", |nodes| {
            nodes
                .into_iter()
                .filter_map(|node| extract_post(node, 1, "fixture"))
                .collect::<Vec<_>>()
        })?;
        assert!(!posts.is_empty());
        assert!(
            posts
                .first()
                .unwrap()
                .get_content()
                .get_raw()
                .contains("测试测试")
        );
        Ok(())
    }

    #[test]
    fn detects_error_page() {
        let html = r#"
            <!--msgcodestart-->5<!--msgcodeend-->
            <!--msginfostart--><span>帖子发布或回复时间超过限制</span><!--msginfoend-->
        "#;

        match detect_nga_error(html).expect("should detect error") {
            ServiceError::Nga(message) => {
                assert_eq!(message.get_code(), "5");
                assert!(message.get_info().contains("帖子发布或回复时间超过限制"));
            }
            other => panic!("unexpected error variant: {other:?}"),
        }
    }
}
