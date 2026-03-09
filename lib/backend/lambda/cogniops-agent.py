import json, time, re, base64
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Key

REGION        = "us-east-1"
MODEL_ID      = "us.anthropic.claude-sonnet-4-6"

dynamodb   = boto3.resource("dynamodb", region_name=REGION)
bedrock    = boto3.client("bedrock-runtime", region_name=REGION)
CHAT_TABLE = dynamodb.Table("ChatMessages")


# Helpers

def resp(code, body):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS,GET,POST",
            "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
        },
        "body": json.dumps(body, default=str),
    }


def now_ts():
    return int(time.time())


def load_history(session_id, limit=20):
    r = CHAT_TABLE.query(
        KeyConditionExpression=Key("sessionId").eq(session_id),
        ScanIndexForward=True,
        Limit=limit,
    )
    msgs = []
    for it in r.get("Items", []):
        role    = it.get("role", "user")
        content = it.get("content", "")
        if content:
            msgs.append({"role": role, "content": content})
    return msgs


def save_msg(session_id, role, content, ts):
    CHAT_TABLE.put_item(Item={
        "sessionId": session_id,
        "timestamp": Decimal(ts),
        "role":      role,
        "content":   content,
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts)),
    })


def mermaid_to_url(code: str):
    if not code:
        return None
    return "https://mermaid.ink/img/" + base64.b64encode(code.encode()).decode()


def split_text_mermaid(full: str):
    full = (full or "").strip()
    for keyword in ["flowchart td", "flowchart lr", "graph td", "graph lr"]:
        idx = full.lower().find(keyword)
        if idx != -1:
            return full[:idx].strip(), full[idx:].strip()
    return full, None


# Action detection

def detect_action(text: str, mode: str = "student") -> dict:
    t = text.lower().strip()
    if any(k in t for k in ["quiz", "mcq", "test me", "questions on"]):
        level = "hard"   if any(k in t for k in ["hard", "difficult", "advanced"]) \
           else "medium" if any(k in t for k in ["medium", "moderate"]) \
           else "easy"
        return {"action": "quiz", "level": level}
    if any(k in t for k in ["flashcard", "flash card"]):
        if mode != "dev":
            return {"action": "flashcards"}
    if any(k in t for k in ["roadmap", "learning path", "study plan", "how to learn", "become a"]):
        return {"action": "roadmap"}
    if any(k in t for k in ["terraform", "iac", "infrastructure as code", "hcl", "generate tf", "write terraform"]):
        return {"action": "terraform"}
    if any(k in t for k in ["architecture", "diagram", "system design", "aws services for", "design a system"]):
        return {"action": "architecture"}
    if any(k in t for k in ["error", "exception", "bug", "failed", "access denied", "debug", "issue", "problem", "not working", "fix this"]):
        return {"action": "debug"}
    if any(k in t for k in ["suggest backend", "based on this code", "analyze this code", "what services", "backend for"]):
        return {"action": "backend_suggest"}
    if any(k in t for k in ["cost", "pricing", "monthly", "bill", "how much"]):
        return {"action": "cost"}
    if any(k in t for k in ["explain", "what is", "what are", "teach", "describe", "how does"]):
        return {"action": "concept"}
    return {"action": "chat"}


# System prompts

STUDENT_BASE = """You are CogniOps Tutor AI — expert mentor for Cloud, DevOps & SRE learners.
Be encouraging, clear, and practical. Teach step-by-step with real examples.
When given a JSON template to fill in, respond ONLY with valid JSON. For plain questions, respond in plain text."""

DEV_BASE = """You are CogniOps Architect AI — senior AWS architect and DevOps expert.
Be technical, precise, and actionable. Think in systems. Propose battle-tested solutions.
When given a JSON template to fill in, respond ONLY with valid JSON. For plain questions, respond in plain text."""

SCHEMA_HEADER = """You MUST respond with ONLY a valid JSON object. No text before or after. No markdown fences.
Fill in the JSON template below exactly as shown, replacing the example values with real content.
"""


#  Tool prompts

def tool_prompt(action: str, meta: dict, user_text: str, mode: str = "student") -> str:

    if action == "quiz":
        lvl   = meta.get("level", "easy")
        count = 5
        return f"""{SCHEMA_HEADER}
{{
  "type": "quiz",
  "assistantText": "Here are your {count} {lvl} questions. Good luck!",
  "data": {{
    "questions": [
      {{
        "q": "Question text?",
        "opts": ["Option A", "Option B", "Option C", "Option D"],
        "ans": 0,
        "explain": "Why this answer is correct"
      }}
    ]
  }}
}}
Generate exactly {count} {lvl} difficulty multiple-choice questions about: {user_text}
Rules: opts array has exactly 4 items (no A/B/C/D prefix), ans is integer 0-3 (correct option index).
"""

    if action == "flashcards":
        return f"""{SCHEMA_HEADER}
{{
  "type": "flashcards",
  "assistantText": "Here are 8 flashcards to help you master this topic!",
  "data": {{
    "cards": [
      {{ "front": "Term or question", "back": "Definition or answer" }}
    ]
  }}
}}
Generate exactly 8 flashcards about: {user_text}
Each card: front = short question or term, back = clear answer or definition.
"""

    if action == "roadmap":
        return f"""{SCHEMA_HEADER}
{{
  "type": "roadmap",
  "assistantText": "Here is your personalised learning roadmap! Want to start with a quiz on Week 1 topics?",
  "data": {{
    "goal": "the goal",
    "title": "Roadmap Title",
    "weeks": [
      {{
        "week": 1,
        "title": "Week title",
        "topics": ["topic 1", "topic 2", "topic 3"],
        "done": false
      }}
    ]
  }}
}}
Create a learning roadmap for: {user_text}
RULES: weeks array must have 6-8 items. Each week needs: week (number), title (string), topics (array of 3-5 strings), done (false). No other keys.
"""

    if action == "concept":
        followup = ("Want me to generate flashcards or a quiz on this topic?"
                    if mode == "student" else
                    "Want me to generate a Terraform template or architecture diagram for this?")
        return f"""{SCHEMA_HEADER}
{{
  "type": "concept",
  "assistantText": "2-3 sentence introduction. End with: {followup}",
  "data": {{
    "sections": [
      {{
        "title": "Section Title",
        "points": ["Key point 1", "Key point 2", "Key point 3"]
      }}
    ]
  }}
}}
Explain this topic clearly with 3-5 sections: {user_text}
"""

    if action == "debug":
        return f"""{SCHEMA_HEADER}
            {{
              "type": "debug",
              "assistantText": "1-2 sentence empathetic opener about the error.",
              "data": {{
                "questions": ["One targeted diagnostic question"],
                "likelyCauses": ["Most likely cause with brief reason"],
                "fixSteps": ["Step 1: specific action", "Step 2: verify with this command"]
              }}
            }}
            Debug this error: {user_text}
            RULES: Be concise. Exactly 1 diagnostic question, 1 likely cause, 2 fix steps.
            """

    if action == "terraform":
        return f"""{SCHEMA_HEADER}
{{
  "type": "terraform",
  "assistantText": "One sentence describing what this Terraform creates. End with: Want me to generate a visual architecture diagram?",
  "data": {{
    "terraform": "provider \"aws\" {{\n  region = \"us-east-1\"\n}}\n# ... rest of HCL",
    "notes": ["Important note 1", "Security recommendation"]
  }}
}}
Generate production-ready Terraform HCL for: {user_text}
The terraform value must be valid HCL with \n for newlines (escaped in JSON string).
"""

    if action == "backend_suggest":
        return f"""{SCHEMA_HEADER}
{{
  "type": "backend_suggest",
  "assistantText": "1 sentence summary of the recommended stack. Want me to generate a visual architecture diagram?",
  "data": {{
    "suggestedServices": ["Lambda — serverless compute", "DynamoDB — NoSQL database"],
    "apiEndpoints": ["POST /api/resource — create resource", "GET /api/resource/{{id}} — fetch resource"],
    "db": ["DynamoDB — fast, scalable NoSQL"],
    "notes": ["Key architectural note"]
  }}
}}
Suggest AWS backend services for: {user_text}
RULES: Max 4 services, 3 endpoints, 1 db choice. Be concise and specific.
"""

    if action == "cost":
        return f"""{SCHEMA_HEADER}
{{
  "type": "cost",
  "assistantText": "2-3 sentence summary of estimated costs and key assumptions.",
  "data": {{
    "estimateMonthlyUSD": 45.00,
    "breakdown": [
      "EC2 t3.medium (2 instances): $30/month",
      "RDS db.t3.small: $25/month"
    ],
    "cheaperAlternatives": ["Use Fargate instead of EC2 to pay per task", "Use Aurora Serverless for variable DB load"],
    "assumptions": ["1000 daily active users", "50GB storage"]
  }}
}}
Estimate monthly AWS cost for: {user_text}
The estimateMonthlyUSD must be a number (not a string). breakdown must be an array of strings.
"""

    # chat fallback — plain response, no strict JSON needed
    followup = ("If you explain a concept, end with: Want me to generate flashcards on this topic?"
                if mode == "student" else
                "Do not mention flashcards. You may suggest architecture diagrams or Terraform if relevant.")
    return f"""Respond naturally and helpfully to: {user_text}

Provide a clear, concise answer. {followup}
Respond in plain text only - no JSON formatting."""


# Bedrock call 

def call_bedrock(system_text: str, messages: list, max_tokens: int = 1500, model_id: str = None) -> str:
    r = bedrock.invoke_model(
        modelId=model_id or MODEL_ID,
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens":        max_tokens,
            "system":            system_text,
            "messages":          messages,
        }),
    )
    return json.loads(r["body"].read())["content"][0]["text"]


def extract_json(text: str) -> dict:
    t = (text or "").strip()
    t = re.sub(r'^```(?:json)?\s*', '', t, flags=re.MULTILINE)
    t = re.sub(r'\s*```\s*$',       '', t, flags=re.MULTILINE)
    t = t.strip()
    if t.lower().startswith("json"):
        rest = t[4:].strip()
        if rest.startswith("{"):
            t = rest
    m = re.search(r'\{.*\}', t, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(0))
        except json.JSONDecodeError:
            pass
    return json.loads(t)


# Lambda handler part

def lambda_handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return resp(200, {"ok": True})

    try:
        body       = json.loads(event.get("body") or "{}")
        session_id = (body.get("sessionId") or "").strip()
        mode       = (body.get("mode")      or "student").lower().strip()
        user_text  = (body.get("message")   or "").strip()

        if not session_id or not user_text:
            return resp(400, {"error": "sessionId and message required"})

        history     = load_history(session_id, limit=20)
        meta        = detect_action(user_text, mode)
        action      = meta["action"]
        system_text = STUDENT_BASE if mode == "student" else DEV_BASE

        #  Architecture 
        if action == "architecture":
            is_dev = mode == "dev"
            instruction = f"""Return ONLY valid JSON, no text outside it:
{{
  "type": "architecture",
  "assistantText": "3-4 sentence explanation of the architecture. End with: Want me to generate a visual architecture diagram for this?",
  "redirectToArchitect": {"true" if is_dev else "false"},
  "data": {{
    "services": ["AWS Service 1", "AWS Service 2"],
    "title": "Architecture title"
  }},
  "mermaid": "flowchart TD\\n  A[User] --> B[CloudFront]\\n  B --> C[ALB]\\n  C --> D[EC2]"
}}

Rules:
- mermaid must be a valid flowchart TD diagram (\\n for newlines in JSON string)
- Keep mermaid under 15 nodes
- assistantText must be plain text only
- services must be real AWS service names

User request: {user_text}"""

            messages = history + [{"role": "user", "content": instruction}]
            raw      = call_bedrock(system_text, messages, max_tokens=1500)

            try:
                model_json = extract_json(raw)
                model_json.setdefault("type", "architecture")
                model_json.setdefault("assistantText", "Architecture generated successfully.")
                model_json.setdefault("redirectToArchitect", is_dev)
                model_json.setdefault("data", {})
                mc = model_json.get("mermaid")
                if isinstance(mc, str) and mc.strip():
                    mc = mc.strip()
                    model_json["mermaid"]    = mc
                    model_json["diagramUrl"] = mermaid_to_url(mc)
                else:
                    model_json["mermaid"]    = None
                    model_json["diagramUrl"] = None
            except Exception as e:
                print(f"Architecture parse error: {e} | raw[:300]: {raw[:300]}")
                text_part, mermaid_code = split_text_mermaid(raw)
                model_json = {
                    "type":                "architecture",
                    "assistantText":       text_part or raw.strip(),
                    "redirectToArchitect": is_dev,
                    "data":                {},
                    "mermaid":             mermaid_code,
                    "diagramUrl":          mermaid_to_url(mermaid_code) if mermaid_code else None,
                }

        # All other actions 
        else:
            instruction = tool_prompt(action, meta, user_text, mode)
            messages    = history + [{"role": "user", "content": instruction}]

            max_tok = {
                "terraform":       900,
                "roadmap":        2500,
                "quiz":            800,
                "flashcards":      700,
                "concept":         800,
                "debug":           700,
                "backend_suggest": 700,
                "cost":           1200,
                "chat":            600,
            }.get(action, 700)

            raw = call_bedrock(
                system_text, messages,
                max_tokens=max_tok,
                model_id=MODEL_ID,
            )

            # For plain chat — skip JSON parsing, just use the raw text
            if action == "chat":
                model_json = {
                    "type":          "chat",
                    "assistantText": raw.strip(),
                    "data":          {},
                    "mermaid":       None,
                    "diagramUrl":    None,
                }
            else:
                try:
                    model_json = extract_json(raw)
                    model_json.setdefault("type",          action)
                    model_json.setdefault("assistantText", "")
                    model_json.setdefault("data",          {})
                    model_json.setdefault("mermaid",       None)

                    # Normalise quiz
                    if action == "quiz":
                        data = model_json.get("data", {})
                        if "questions" not in data:
                            qs = model_json.get("questions") or model_json.get("items") or []
                            if qs:
                                data["questions"] = qs
                        for q in data.get("questions", []):
                            if isinstance(q, dict):
                                if "options" in q and "opts" not in q:
                                    q["opts"] = q.pop("options")
                                if "answerIndex" in q and "ans" not in q:
                                    q["ans"] = q.pop("answerIndex")
                                if "question" in q and "q" not in q:
                                    q["q"] = q.pop("question")
                                if "explanation" in q and "explain" not in q:
                                    q["explain"] = q.pop("explanation")
                        model_json["data"] = data

                    # Normalise cost — model 
                    if action == "cost":
                        import re as _re
                        data = model_json.get("data", {})
                        # If estimateMonthlyUSD is at top level, move it into data
                        for key in ["estimateMonthlyUSD", "breakdown", "cheaperAlternatives", "assumptions", "services"]:
                            if key in model_json and key not in data:
                                data[key] = model_json[key]
                        # Safe numeric conversion
                        est = data.get("estimateMonthlyUSD", 0)
                        if isinstance(est, str):
                            data["estimateMonthlyUSD"] = float(_re.sub(r"[^0-9.]", "", est) or "0")
                        elif not isinstance(est, (int, float)):
                            data["estimateMonthlyUSD"] = 0.0
                        # Ensure breakdown is a list of strings
                        breakdown = data.get("breakdown", [])
                        if isinstance(breakdown, list):
                            data["breakdown"] = [
                                (f"{b.get('service', b.get('name',''))}: ${b.get('cost', b.get('monthlyCost',''))}"
                                 if isinstance(b, dict) else str(b))
                                for b in breakdown
                            ]
                        model_json["data"] = data
                        model_json["assistantText"] = model_json.get("assistantText", "") or (
                            f"Estimated monthly cost: ${data.get('estimateMonthlyUSD', 0):.2f}")

                    # Normalise roadmap weeks
                    if action == "roadmap":
                        data = model_json.get("data", {})
                        if "stages" in data and "weeks" not in data:
                            data["weeks"] = [
                                {
                                    "week":   i + 1,
                                    "title":  s.get("title", f"Stage {i+1}"),
                                    "topics": s.get("topics", s.get("skills", s.get("content", []))),
                                    "done":   False,
                                }
                                for i, s in enumerate(data["stages"])
                            ]
                        for i, w in enumerate(data.get("weeks", [])):
                            if isinstance(w, dict):
                                w["week"]   = w.get("week", i + 1)
                                w["title"]  = w.get("title", w.get("name", f"Week {i+1}"))
                                w["topics"] = w.get("topics", w.get("skills", w.get("content", [])))
                                w["done"]   = False
                                w.pop("resources",   None)
                                w.pop("miniProject", None)
                                w.pop("milestones",  None)
                        model_json["data"] = data

                    mc = model_json.get("mermaid")
                    model_json["diagramUrl"] = mermaid_to_url(mc.strip()) \
                        if isinstance(mc, str) and mc.strip() else None

                except Exception as parse_err:
                    print(f"JSON parse error: {parse_err} | raw[:300]: {raw[:300]}")
                    model_json = {
                        "type":          action,
                        "assistantText": raw.strip(),
                        "data":          {},
                        "mermaid":       None,
                        "diagramUrl":    None,
                    }

        #  Persist to DynamoDB 
        ts = now_ts()
        save_msg(session_id, "user",      user_text,                           ts)
        save_msg(session_id, "assistant", model_json.get("assistantText", ""), ts + 1)

        return resp(200, model_json)

    except Exception as e:
        import traceback
        print("FATAL ERROR:", traceback.format_exc())
        return resp(500, {"error": str(e)})
