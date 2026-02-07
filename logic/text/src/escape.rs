fn parse_decimal_entity(text: &str, start: usize) -> Option<(u32, usize)> {
    let bytes = text.as_bytes();
    if start + 3 > bytes.len() || &bytes[start..start + 2] != b"&#" {
        return None;
    }
    let mut i = start + 2;
    let mut value = 0u32;
    let mut has_digit = false;
    while i < bytes.len() {
        match bytes[i] {
            b'0'..=b'9' => {
                has_digit = true;
                value = value
                    .saturating_mul(10)
                    .saturating_add((bytes[i] - b'0') as u32);
                i += 1;
            }
            b';' if has_digit => return Some((value, i + 1)),
            _ => return None,
        }
    }
    None
}

fn push_decimal_entity(out: &mut String, value: u32) {
    out.push_str("&#");
    out.push_str(&value.to_string());
    out.push(';');
}

fn decode_surrogate_entity_pairs(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut i = 0;
    while i < text.len() {
        if let Some((high, next)) = parse_decimal_entity(text, i)
            && (0xD800..=0xDBFF).contains(&high)
            && let Some((low, end)) = parse_decimal_entity(text, next)
            && (0xDC00..=0xDFFF).contains(&low)
            && let Some(Ok(c)) = char::decode_utf16([high as u16, low as u16]).next()
        {
            out.push(c);
            i = end;
            continue;
        }

        let mut iter = text[i..].chars();
        if let Some(c) = iter.next() {
            out.push(c);
            i += c.len_utf8();
        } else {
            break;
        }
    }
    out
}

pub fn unescape(text: &str) -> String {
    // todo: Cow
    let first = html_escape::decode_html_entities(text);
    let second = html_escape::decode_html_entities(&first);
    decode_surrogate_entity_pairs(&second)
}

pub fn escape_for_submit(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        let cp = c as u32;
        // Escape characters that legacy NGA endpoints tend to reject or
        // mis-handle unless represented as numeric entities.
        let needs_escape = cp > 0xFFFF
            // Zero-width joiner: used by emoji ZWJ sequences (family/profession).
            || cp == 0x200D
            // Variation selectors: e.g. force emoji presentation in "❤️".
            || (0xFE00..=0xFE0F).contains(&cp)
            // Misc Symbols + Dingbats: contains many legacy emoji-like symbols.
            || (0x2600..=0x27BF).contains(&cp);
        if needs_escape {
            // Keep compatibility with legacy endpoints that decode numeric entities
            // via UTF-16 code units.
            let mut buf = [0u16; 2];
            for unit in c.encode_utf16(&mut buf).iter() {
                push_decimal_entity(&mut out, *unit as u32);
            }
        } else {
            out.push(c);
        }
    }
    out
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_unescape() {
        let text = "&amp;#128514;&amp;#128513;";
        let unescaped = unescape(text);
        println!("{}", unescaped);
        assert_eq!(unescaped, "😂😁");
    }

    #[test]
    fn test_unescape_surrogate_entities() {
        let text = "&amp;#55357;&amp;#56836;";
        let unescaped = unescape(text);
        assert_eq!(unescaped, "😄");
    }

    #[test]
    fn test_escape_for_submit() {
        let text = "A😂B❤️C👨‍👩‍👧‍👦";
        let escaped = escape_for_submit(text);
        assert_eq!(
            escaped,
            "A&#55357;&#56834;B&#10084;&#65039;C&#55357;&#56424;&#8205;&#55357;&#56425;&#8205;&#55357;&#56423;&#8205;&#55357;&#56422;"
        );
    }
}
