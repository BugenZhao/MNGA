# NGA `follow_v2.get_push_list` (`lite=xml`) API Notes

This document describes the endpoint behind **My → Followed Activity** (`关注动态`) on `nga.178.com`, focusing on the `lite=xml` output format.

## Endpoint

- Method: `POST`
- URL: `https://nga.178.com/nuke.php?__lib=follow_v2&__act=get_push_list&page={page}`
- Body (form): `__output={output}`
- Authentication: requires valid NGA login cookies (same-origin request).

### Parameters

- `page` (query, integer, 1-based): page index.
- `lite=xml` (query, flag): forces an XML response (`text/xml; charset=GB18030`) regardless of `__output`.
- `__output` (form, integer/string): still required by the endpoint, but when `lite=xml` is present it no longer changes the response format.

## Character encoding

With `lite=xml`, the response uses `charset=GB18030`.

## Response data model (XML)

`lite=xml` returns a root node containing `data` and `time`:

```xml
<?xml version="1.0" encoding="GB18030"?>
<root>
  <data>...</data>
  <time>...</time>
</root>
```

### `data[0]`: activity list (index-based fields)

Each activity entry is a small object with numeric keys plus a `summary` string.

Observed field mapping (as used by the site UI):

- `v[0]`: activity id
- `v[1]`: activity type
  - `1`: followed user posted a topic
  - `2`: followed user posted a reply
  - `3`: followed user favorited a topic/reply
- `v[2]`: actor uid (poster or favoriter)
- `v[3]`: `tid`
- `v[4]`: `pid` (0 means topic)
- `v[5]`: reply-to pid (only meaningful for reply flows)
- `v[6]`: timestamp (unix seconds)
- `v[7]`: favorite table id (only for type `3`)
- `summary`: UBB-like human-readable summary

### `data[1]`: users map (keyed by uid)

Users are keyed by UID (string). Each entry contains fields like:

- `uid`, `username`, `groupid`, `memberid`, `medal`, `reputation`, `postnum`, `money`, `thisvisit`, `bit_data`, ...

### `data[4]`: topics map (keyed by tid)

Topics are keyed by TID (string). Each entry contains fields like:

- `tid`, `fid`, `author`, `authorid`, `subject`, `postdate`, `lastpost`, `lastposter`, `replies`, `content`, `tpcurl`, `parent`, ...

### Pagination

- `data[2]`: max page (number)
- `data[3]`: current page (number)
- `time`: server time (unix seconds)

## UI rendering behavior (where the table comes from)

The **table rows** are driven by `data[0]` (activity list), but the **display text** is resolved through `data[1]` and `data[4]`:

- Username/link: `users[uid].username` (from `data[1]`)
- Topic subject/link: `topics[tid].subject` and `/read.php?tid=...` (from `data[4]`)

This is implemented in the frontend function `commonui.myfollow.get_push_list`, which reads:

- `da = d.data[0]` (activities)
- `users = d.data[1]`
- `posts = d.data[4]`

and renders a `table.forumbox` where each row uses `users[uid]` + `posts[tid]` for display.

## Example (`lite=xml`)

Request:

```
POST /nuke.php?__lib=follow_v2&__act=get_push_list&page=1&lite=xml
Content-Type: application/x-www-form-urlencoded

__output=3
```

Response (structure):

```xml
<?xml version="1.0" encoding="GB18030"?>
<root>
  <data>
    <!-- data[0]: activity list -->
    <item>
      <item>
        <item>12070836</item>
        <item>1</item>
        <item>465855</item>
        <item>45727480</item>
        <item>0</item>
        <item>0</item>
        <item>1764909093</item>
        <item>0</item>
        <item>0</item>
        <summary>[summary omitted]</summary>
      </item>
      <!-- more activity items ... -->
    </item>

    <!-- data[1]: users -->
    <item>
      <item>
        <uid>465855</uid>
        <username>[username omitted]</username>
        <credit>169083394</credit>
        <medal>...</medal>
        <reputation>...</reputation>
        <groupid>-1</groupid>
        <memberid>39</memberid>
        <postnum>3531</postnum>
        <money>31004</money>
        <thisvisit>1765853518</thisvisit>
        <bit_data>169083394</bit_data>
      </item>
      <!-- more users ... -->
    </item>

    <!-- data[2]: max page -->
    <item>1</item>

    <!-- data[3]: current page -->
    <item>1</item>

    <!-- data[4]: topics -->
    <item>
      <item>
        <tid>45727480</tid>
        <fid>685</fid>
        <author>[username omitted]</author>
        <authorid>465855</authorid>
        <subject>[subject omitted]</subject>
        <postdate>1764909093</postdate>
        <replies>0</replies>
        <content>[content omitted]</content>
        <tpcurl>/read.php?tid=45727480</tpcurl>
        <parent>
          <_0>685</_0>
          <_2>[forum title omitted]</_2>
        </parent>
      </item>
      <!-- more topics ... -->
    </item>
  </data>
  <time>1765977844</time>
</root>
```
