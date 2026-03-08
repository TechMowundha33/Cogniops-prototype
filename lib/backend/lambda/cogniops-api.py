import json
import os
import uuid
import time
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key


# Environment
# ─────────────────────────────────────────────────────────────────────────────
REGION         = os.getenv("AWS_REGION", "us-east-1")
MODEL_ID       = os.getenv("MODEL_ID", "us.anthropic.claude-sonnet-4-6")

USERS_TABLE    = os.getenv("USERS_TABLE",    "Users")
SESSIONS_TABLE = os.getenv("SESSIONS_TABLE", "ChatSessions")
MESSAGES_TABLE = os.getenv("MESSAGES_TABLE", "ChatMessages")
PROGRESS_TABLE = os.getenv("PROGRESS_TABLE", "UserProgress")   # NEW
ROADMAP_TABLE  = os.getenv("ROADMAP_TABLE",  "UserRoadmaps")   # NEW
QUIZ_TABLE     = os.getenv("QUIZ_TABLE",     "QuizResults")    # NEW

# ─────────────────────────────────────────────────────────────────────────────
# AWS clients
# ─────────────────────────────────────────────────────────────────────────────
bedrock      = boto3.client("bedrock-runtime", region_name=REGION)
dynamodb     = boto3.resource("dynamodb",       region_name=REGION)

users_tbl    = dynamodb.Table(USERS_TABLE)
sessions_tbl = dynamodb.Table(SESSIONS_TABLE)
messages_tbl = dynamodb.Table(MESSAGES_TABLE)
progress_tbl = dynamodb.Table(PROGRESS_TABLE)
roadmap_tbl  = dynamodb.Table(ROADMAP_TABLE)
quiz_tbl     = dynamodb.Table(QUIZ_TABLE)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def _now_ms() -> int:
    return int(time.time() * 1000)

def _resp(status: int, body: dict):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
        },
        "body": json.dumps(body, default=str),
    }

def _get_body(event) -> dict:
    raw = event.get("body")
    if raw is None:
        return {}
    if isinstance(raw, dict):
        return raw
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}

def _get_user_id(event, body: dict) -> str:
    """
    Priority:
    1. Cognito JWT claims (when API Gateway has Cognito authorizer)
    2. userId in request body (fallback for testing)
    """
    # Try Cognito JWT first
    try:
        claims = event["requestContext"]["authorizer"]["claims"]
        return claims.get("sub") or claims.get("cognito:username") or ""
    except (KeyError, TypeError):
        pass
    # Fallback: body userId
    return (body.get("userId") or "demo-user").strip()

def _decimal_to_num(obj):
    """Convert DynamoDB Decimal to int/float for JSON serialization."""
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj

def _clean_item(item: dict) -> dict:
    """Recursively convert Decimals in a DynamoDB item."""
    return {k: (_decimal_to_num(v) if isinstance(v, Decimal) else v)
            for k, v in item.items()}

# ─────────────────────────────────────────────────────────────────────────────
# Lambda handler
# ─────────────────────────────────────────────────────────────────────────────
def lambda_handler(event, context):
    method = event.get("httpMethod", "GET")
    path   = (event.get("path") or "").rstrip("/") or "/"

    # CORS preflight
    if method == "OPTIONS":
        return _resp(200, {"ok": True})

    # ─── 1. Health ────────────────────────────────────────────────────────────
    if path == "/health" and method == "GET":
        return _resp(200, {
            "ok": True, "service": "cogniops-api",
            "region": REGION, "modelId": MODEL_ID, "time": _now_iso(),
        })

    body    = _get_body(event)
    user_id = _get_user_id(event, body)

    # ─── 2. Profile ───────────────────────────────────────────────────────────
    # GET  /profile          → fetch user profile
    # POST /profile          → create/update user profile (called after Cognito signup)
    if path == "/profile":
        if method == "GET":
            qs    = event.get("queryStringParameters") or {}
            uid   = (qs.get("userId") or user_id).strip()
            try:
                res  = users_tbl.get_item(Key={"userId": uid})
                item = res.get("Item")
                if not item:
                    return _resp(404, {"error": "Profile not found"})
                return _resp(200, _clean_item(item))
            except Exception as e:
                return _resp(500, {"error": str(e)})

        if method == "POST":
            name  = (body.get("name")  or "").strip()
            email = (body.get("email") or "").strip()
            role  = (body.get("role")  or "student").strip()
            if not name or not email:
                return _resp(400, {"error": "name and email required"})

            now = _now_iso()
            # Use update so we don't wipe existing xp/streak
            users_tbl.update_item(
                Key={"userId": user_id},
                UpdateExpression=(
                    "SET #n = :n, email = :e, #r = :r, updatedAt = :u, "
                    "createdAt = if_not_exists(createdAt, :u), "
                    "xp        = if_not_exists(xp, :zero), "
                    "streak    = if_not_exists(streak, :zero), "
                    "quizCount = if_not_exists(quizCount, :zero), "
                    "modulesCompleted = if_not_exists(modulesCompleted, :zero)"
                ),
                ExpressionAttributeNames={"#n": "name", "#r": "role"},
                ExpressionAttributeValues={
                    ":n": name, ":e": email, ":r": role,
                    ":u": now, ":zero": 0,
                },
            )
            return _resp(200, {"ok": True, "userId": user_id})

    # ─── 3. Sessions ──────────────────────────────────────────────────────────
    if path == "/sessions":
        if method == "POST":
            session_id = str(uuid.uuid4())
            created_at = _now_iso()
            title      = (body.get("title") or "New chat").strip()
            sessions_tbl.put_item(Item={
                "userId": user_id, "sessionId": session_id,
                "title": title, "createdAt": created_at, "updatedAt": created_at,
            })
            return _resp(201, {"sessionId": session_id, "title": title, "createdAt": created_at})

        if method == "GET":
            qs     = event.get("queryStringParameters") or {}
            q_user = (qs.get("userId") or user_id).strip()
            res    = sessions_tbl.query(KeyConditionExpression=Key("userId").eq(q_user))
            items  = res.get("Items", [])
            items.sort(key=lambda x: x.get("updatedAt", ""), reverse=True)
            return _resp(200, {"userId": q_user, "sessions": items})

    # ─── 4. Messages ──────────────────────────────────────────────────────────
    if path == "/messages" and method == "GET":
        qs         = event.get("queryStringParameters") or {}
        session_id = (qs.get("sessionId") or "").strip()
        limit      = int(qs.get("limit") or 50)
        if not session_id:
            return _resp(400, {"error": "sessionId required"})
        res = messages_tbl.query(
            KeyConditionExpression=Key("sessionId").eq(session_id),
            Limit=limit, ScanIndexForward=True,
        )
        items = [_clean_item(i) for i in res.get("Items", [])]
        return _resp(200, {"sessionId": session_id, "messages": items})

    if path == "/messages" and method == "POST":
        session_id = (body.get("sessionId") or "").strip()
        role       = (body.get("role")      or "user").strip()
        content    = (body.get("content")   or "").strip()
        if not session_id or not content:
            return _resp(400, {"error": "sessionId and content required"})
        ts = _now_ms()
        messages_tbl.put_item(Item={
            "sessionId": session_id, "timestamp": ts,
            "userId": user_id, "role": role, "content": content,
            "createdAt": _now_iso(),
        })
        # Update session updatedAt
        sessions_tbl.update_item(
            Key={"userId": user_id, "sessionId": session_id},
            UpdateExpression="SET updatedAt = :u",
            ExpressionAttributeValues={":u": _now_iso()},
            ConditionExpression="attribute_exists(sessionId)",
        ) if user_id else None
        return _resp(201, {"ok": True, "timestamp": ts})

    # ─── 5. Chat (simple reply - uses cogniops_api bedrock, not agent) ────────
    if path == "/chat" and method == "POST":
        session_id   = (body.get("sessionId") or "").strip()
        user_message = (body.get("message")   or "").strip()
        if not session_id or not user_message:
            return _resp(400, {"error": "sessionId and message required"})

        ts_user = _now_ms()
        messages_tbl.put_item(Item={
            "sessionId": session_id, "timestamp": ts_user,
            "userId": user_id, "role": "user", "content": user_message,
            "createdAt": _now_iso(),
        })

        ai_text = _bedrock_reply(user_message)

        ts_ai = ts_user + 1
        messages_tbl.put_item(Item={
            "sessionId": session_id, "timestamp": ts_ai,
            "userId": user_id, "role": "assistant", "content": ai_text,
            "createdAt": _now_iso(),
        })

        title = user_message[:48]
        sessions_tbl.update_item(
            Key={"userId": user_id, "sessionId": session_id},
            UpdateExpression="SET updatedAt = :u, title = :t",
            ExpressionAttributeValues={":u": _now_iso(), ":t": title},
        )
        return _resp(200, {"reply": ai_text})

    # ─── 6. Progress ──────────────────────────────────────────────────────────
    # GET  /progress?userId=...
    # POST /progress  { xpDelta, streakReset?, modulesCompletedDelta? }
    if path == "/progress":
        if method == "GET":
            qs  = event.get("queryStringParameters") or {}
            uid = (qs.get("userId") or user_id).strip()
            try:
                res  = users_tbl.get_item(Key={"userId": uid})
                item = res.get("Item", {})
                return _resp(200, {
                    "userId":           uid,
                    "xp":               _decimal_to_num(item.get("xp", 0)),
                    "streak":           _decimal_to_num(item.get("streak", 0)),
                    "quizCount":        _decimal_to_num(item.get("quizCount", 0)),
                    "modulesCompleted": _decimal_to_num(item.get("modulesCompleted", 0)),
                    "lastActiveDate":   item.get("lastActiveDate", ""),
                })
            except Exception as e:
                return _resp(500, {"error": str(e)})

        if method == "POST":
            xp_delta      = int(body.get("xpDelta", 0))
            streak_reset  = bool(body.get("streakReset", False))
            modules_delta = int(body.get("modulesCompletedDelta", 0))
            today         = datetime.now(timezone.utc).strftime("%Y-%m-%d")

            try:
                # Get current to compute streak
                res  = users_tbl.get_item(Key={"userId": user_id})
                item = res.get("Item", {})
                last = item.get("lastActiveDate", "")

                # Streak logic: increment if last active was yesterday, reset if >1 day gap
                current_streak = int(item.get("streak", 0))
                if streak_reset:
                    new_streak = 0
                elif last == today:
                    new_streak = current_streak  # same day, no change
                else:
                    from datetime import date, timedelta
                    try:
                        last_date = date.fromisoformat(last)
                        yesterday = date.today() - timedelta(days=1)
                        new_streak = current_streak + 1 if last_date == yesterday else 1
                    except Exception:
                        new_streak = 1

                users_tbl.update_item(
                    Key={"userId": user_id},
                    UpdateExpression=(
                        "SET xp               = if_not_exists(xp, :zero) + :xp, "
                        "    streak           = :streak, "
                        "    lastActiveDate   = :today, "
                        "    quizCount        = if_not_exists(quizCount, :zero), "
                        "    modulesCompleted = if_not_exists(modulesCompleted, :zero) + :md"
                    ),
                    ExpressionAttributeValues={
                        ":xp":     xp_delta,
                        ":streak": new_streak,
                        ":today":  today,
                        ":zero":   0,
                        ":md":     modules_delta,
                    },
                )
                return _resp(200, {"ok": True, "newStreak": new_streak})
            except Exception as e:
                return _resp(500, {"error": str(e)})

    # ─── 7. Quiz Results ──────────────────────────────────────────────────────
    # GET  /quiz-results?userId=...&limit=10
    # POST /quiz-results  { topic, difficulty, score, total, xpEarned }
    if path == "/quiz-results":
        if method == "POST":
            topic      = (body.get("topic")      or "General").strip()
            difficulty = (body.get("difficulty") or "Easy").strip()
            score      = int(body.get("score",  0))
            total      = int(body.get("total",  1))
            xp_earned  = int(body.get("xpEarned", 0))
            pct        = round(score / total * 100) if total > 0 else 0
            result_id  = str(uuid.uuid4())
            now        = _now_iso()

            quiz_tbl.put_item(Item={
                "userId":     user_id,
                "resultId":   result_id,
                "topic":      topic,
                "difficulty": difficulty,
                "score":      score,
                "total":      total,
                "pct":        pct,
                "xpEarned":  xp_earned,
                "createdAt":  now,
            })

            # Also bump quizCount on Users table
            users_tbl.update_item(
                Key={"userId": user_id},
                UpdateExpression="ADD quizCount :one",
                ExpressionAttributeValues={":one": 1},
            )

            return _resp(201, {"ok": True, "resultId": result_id, "pct": pct})

        if method == "GET":
            qs    = event.get("queryStringParameters") or {}
            uid   = (qs.get("userId") or user_id).strip()
            limit = int(qs.get("limit") or 10)
            try:
                res   = quiz_tbl.query(
                    KeyConditionExpression=Key("userId").eq(uid),
                    Limit=limit,
                    ScanIndexForward=False,  # newest first
                )
                items = [_clean_item(i) for i in res.get("Items", [])]
                return _resp(200, {"userId": uid, "results": items})
            except Exception as e:
                return _resp(500, {"error": str(e)})

    # ─── 8. Roadmap ───────────────────────────────────────────────────────────
    # GET  /roadmap?userId=...
    # POST /roadmap  { goal, weeks: [...], title }
    # PUT  /roadmap  { roadmapId, weekIndex, done: bool }  (mark week complete)
    if path == "/roadmap":
        if method == "GET":
            qs  = event.get("queryStringParameters") or {}
            uid = (qs.get("userId") or user_id).strip()
            try:
                res  = roadmap_tbl.get_item(Key={"userId": uid})
                item = res.get("Item")
                if not item:
                    return _resp(200, {"userId": uid, "roadmap": None})
                return _resp(200, {"userId": uid, "roadmap": _clean_item(item)})
            except Exception as e:
                return _resp(500, {"error": str(e)})

        if method == "POST":
            goal  = (body.get("goal")  or "").strip()
            title = (body.get("title") or goal).strip()
            weeks = body.get("weeks", [])
            if not goal or not weeks:
                return _resp(400, {"error": "goal and weeks required"})
            now = _now_iso()
            roadmap_tbl.put_item(Item={
                "userId":    user_id,
                "goal":      goal,
                "title":     title,
                "weeks":     json.dumps(weeks),  # store as JSON string
                "createdAt": now,
                "updatedAt": now,
            })
            return _resp(200, {"ok": True})

        if method == "PUT":
            week_index = int(body.get("weekIndex", 0))
            done       = bool(body.get("done", False))
            try:
                res  = roadmap_tbl.get_item(Key={"userId": user_id})
                item = res.get("Item")
                if not item:
                    return _resp(404, {"error": "No roadmap found"})
                weeks = json.loads(item.get("weeks", "[]"))
                if 0 <= week_index < len(weeks):
                    weeks[week_index]["done"] = done
                roadmap_tbl.update_item(
                    Key={"userId": user_id},
                    UpdateExpression="SET weeks = :w, updatedAt = :u",
                    ExpressionAttributeValues={":w": json.dumps(weeks), ":u": _now_iso()},
                )
                return _resp(200, {"ok": True})
            except Exception as e:
                return _resp(500, {"error": str(e)})

    return _resp(404, {"error": f"No route: {method} {path}"})


# ─────────────────────────────────────────────────────────────────────────────
# Bedrock helper (simple reply for /chat)
# ─────────────────────────────────────────────────────────────────────────────
def _bedrock_reply(user_message: str) -> str:
    prompt = (
        "You are CogniOps AI, a helpful mentor for Cloud/DevOps learners.\n"
        f"User: {user_message}\n"
    )
    resp = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 500,
            "messages": [{"role": "user", "content": prompt}],
        }),
    )
    data = json.loads(resp["body"].read())
    return data["content"][0]["text"]