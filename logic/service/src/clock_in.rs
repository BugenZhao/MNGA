use std::{sync::Mutex, time::Duration};

use cache::CACHE;
use protos::Service::{ClockInRequest, ClockInResponse};
use serde_json::Value;

use crate::{
    auth::current_uid,
    constants::APPLE_UA,
    error::{ServiceError, ServiceResult},
    fetch::{fetch_json_value, with_user_agent},
    utils::server_today_string,
};

/// Daily sign-in missions, listed by `__lib=mission&__act=get&event=1`. `check_in` alone only
/// updates the sign-in streak. The rewards are paid by counting each of these missions.
///
/// - 30: 1 N coin.
/// - 2: 100 copper coins, only for accounts holding less than 19900 copper coins.
///
/// When NGA rejects a mission request, it answers the next one sent within a second with a
/// transient lock error. Mission 2 has the extra requirement, so mission 30 goes first.
const REWARD_MISSION_IDS: [&str; 2] = ["30", "2"];

/// Rounds per day and account in which NGA may reject a mission before giving up. Mainly for
/// accounts that can never finish mission 2, which would otherwise retry for the whole day.
const MAX_REJECTED_ROUNDS: u32 = 5;

static REJECTED_ROUNDS: Mutex<Option<(String, u32)>> = Mutex::new(None);

fn clock_in_key() -> String {
    // Records under the former `/clock_in/user/` prefix only mean that `check_in` was called, so
    // they must not stop the rewards from being claimed.
    format!("/clock_in_v2/user/{}", current_uid())
}

fn clocked_in_today(key: &str) -> ServiceResult<bool> {
    let last = CACHE.get_msg::<ClockInResponse>(key)?;
    Ok(last
        .map(|r| r.date == server_today_string())
        .unwrap_or_default())
}

fn rejected_rounds(scope: &str) -> u32 {
    match &*REJECTED_ROUNDS.lock().unwrap() {
        Some((current, rounds)) if current == scope => *rounds,
        _ => 0,
    }
}

fn record_rejected_round(scope: &str) -> u32 {
    let rounds = rejected_rounds(scope) + 1;
    *REJECTED_ROUNDS.lock().unwrap() = Some((scope.to_owned(), rounds));
    rounds
}

/// Returns whether this call signed in. NGA also rejects it when already signed in today, for
/// example from the official app, which must not stop the rewards from being claimed.
async fn check_in() -> ServiceResult<bool> {
    let result = fetch_json_value(
        "nuke.php",
        vec![("__lib", "check_in"), ("__act", "check_in")],
        vec![],
    )
    .await;

    match result {
        Ok(_) => Ok(true),
        Err(ServiceError::Nga(e)) => {
            log::info!("check_in rejected: {}", e.info);
            Ok(false)
        }
        Err(e) => Err(e),
    }
}

/// Whether this response paid the reward of the mission. Each mission maps to `null` if it has
/// just been counted, or to a code such as `7` if it has already been counted today.
fn mission_counted_now(value: &Value, mission_id: &str) -> bool {
    value
        .get("0")
        .and_then(|results| results.get(mission_id))
        .is_some_and(Value::is_null)
}

async fn claim_reward(mission_id: &str) -> ServiceResult<bool> {
    let value = fetch_json_value(
        "nuke.php",
        vec![
            ("__lib", "mission"),
            ("__act", "checkin_count_add"),
            ("mid", mission_id),
        ],
        vec![],
    )
    .await?;

    Ok(mission_counted_now(&value, mission_id))
}

/// NGA counts the missions only for its own apps, and refuses them for the Desktop and custom
/// identities. So signing in always uses the default identity, whatever the user picked.
pub async fn clock_in(_request: ClockInRequest) -> ServiceResult<ClockInResponse> {
    with_user_agent(APPLE_UA, do_clock_in()).await
}

async fn do_clock_in() -> ServiceResult<ClockInResponse> {
    let mut response = ClockInResponse {
        date: server_today_string(),
        ..Default::default()
    };

    let key = clock_in_key();
    let scope = format!("{key}@{}", response.date);
    if clocked_in_today(&key)? || rejected_rounds(&scope) >= MAX_REJECTED_ROUNDS {
        return Ok(response);
    }

    let signed_in = check_in().await?;
    if signed_in {
        tokio::time::sleep(Duration::from_secs(1)).await;
    }

    let mut claimed = false;
    let mut accepted = false;
    let mut rejection = None;
    for mission_id in REWARD_MISSION_IDS {
        match claim_reward(mission_id).await {
            Ok(now) => {
                accepted = true;
                claimed |= now;
            }
            Err(ServiceError::Nga(e)) => {
                log::warn!("mission {mission_id} rejected: {}", e.info);
                rejection = Some(ServiceError::Nga(e));
            }
            Err(e) => return Err(e),
        }
    }

    if let Some(rejection) = rejection {
        // A rejection may be transient, so try again on the next call. Once the rounds run out,
        // stop for the day only if NGA accepted another mission. Otherwise the account itself
        // may be at fault, which can be fixed before the next launch.
        let exhausted = record_rejected_round(&scope) >= MAX_REJECTED_ROUNDS;
        if !(exhausted && accepted) {
            return Err(rejection);
        }
    }

    let _ = CACHE.insert_msg(&key, &response)?;
    response.is_first_time = signed_in || claimed;

    Ok(response)
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_mission_counted_now() {
        let counted: Value =
            serde_json::from_str(r#"{"0":{"30":null},"1":{"0":{},"2":{"30":"reward"}}}"#).unwrap();
        assert!(mission_counted_now(&counted, "30"));

        let repeated: Value =
            serde_json::from_str(r#"{"0":{"30":7},"1":{"0":{},"1":{}},"2":"done"}"#).unwrap();
        assert!(!mission_counted_now(&repeated, "30"));

        // A mission that is missing from the response has not paid anything.
        assert!(!mission_counted_now(&counted, "2"));
        assert!(!mission_counted_now(&Value::Null, "30"));
    }

    #[test]
    fn test_rejected_rounds_are_scoped() {
        let scope = "/clock_in_v2/user/test@2000-01-01";
        assert_eq!(rejected_rounds(scope), 0);
        assert_eq!(record_rejected_round(scope), 1);
        assert_eq!(record_rejected_round(scope), 2);
        assert_eq!(rejected_rounds("/clock_in_v2/user/test@2000-01-02"), 0);
    }

    #[ignore = "manual: requires network or mutable external state"]
    #[tokio::test]
    async fn test_clock_in() -> ServiceResult<()> {
        clock_in(ClockInRequest::default()).await?;
        assert!(clocked_in_today(&clock_in_key()).unwrap());
        Ok(())
    }
}
