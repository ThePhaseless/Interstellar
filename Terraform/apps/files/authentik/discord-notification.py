# Evaluated by NotificationTransport.send_webhook with user=, request=None and
# notification= in scope; the returned dict replaces the entire POST body.

COLORS = {"notice": 3066993, "warning": 15844367, "alert": 15158332}
ICONS = {
    "model_created": "🆕",
    "model_updated": "✏️",
    "model_deleted": "🗑️",
    "login": "🔓",
    "login_failed": "⛔",
    "logout": "👋",
    "password_set": "🔑",
    "impersonation_started": "🎭",
    "suspicious_request": "🚨",
    "configuration_error": "⚠️",
}

event = notification.event
# The transport test endpoint sends a Notification with no event attached.
if event is None:
    return {
        "username": "authentik",
        "embeds": [
            {
                "title": "🔔 Test notification",
                "description": notification.body,
                "color": COLORS["notice"],
            }
        ],
    }

action = event.action or "event"
context = event.context or {}
model = context.get("model") or {}
http = context.get("http_request") or {}
actor = event.user or {}
actor_name = actor.get("username") or actor.get("email") or "system"

subject = model.get("name") or ""
model_name = model.get("model_name") or ""
link = None
fields = []

if model_name == "user" and model.get("pk"):
    # The event context stores model_to_dict()'s display name, not the username.
    target = ak_user_by(pk=model.get("pk"))
    if target:
        subject = target.username
        link = "${authentik_url}/if/admin/#/identity/users/" + str(model.get("pk"))
        fields.append({"name": "Account", "value": target.username, "inline": True})
        if target.name:
            fields.append({"name": "Name", "value": target.name, "inline": True})
        if target.email:
            fields.append({"name": "Email", "value": target.email, "inline": True})
        fields.append({"name": "Type", "value": str(target.type), "inline": True})
elif model:
    fields.append(
        {
            "name": "Object",
            "value": "{} ({})".format(subject or "—", model_name or "?"),
            "inline": True,
        }
    )

fields.append({"name": "By", "value": actor_name, "inline": True})
if event.client_ip:
    fields.append({"name": "IP", "value": str(event.client_ip), "inline": True})
if http.get("path"):
    fields.append(
        {
            "name": "Request",
            "value": "{} {}".format(http.get("method") or "", http.get("path"))[:1024],
            "inline": False,
        }
    )

# login_failed and friends carry the attempted account here, not in a model.
if not subject and isinstance(context.get("username"), str):
    subject = context.get("username")

if action.startswith("model_"):
    headline = "{} {}".format(
        (model_name or "object").replace("_", " ").capitalize(), action.split("_", 1)[1]
    )
else:
    headline = action.replace("_", " ").capitalize()
if subject:
    headline = "{}: {}".format(headline, subject)

extra = {
    key: value
    for key, value in context.items()
    if key not in ("model", "http_request", "username", "password")
    and isinstance(value, (str, int, float, bool))
}
description = ", ".join("**{}**: {}".format(k, v) for k, v in extra.items())[:2000]

embed = {
    "title": "{} {}".format(ICONS.get(action, "🔔"), headline)[:256],
    "color": COLORS.get(notification.severity, COLORS["notice"]),
    "fields": fields[:25],
    "footer": {"text": "authentik · {}".format(action)},
    "timestamp": event.created.isoformat(),
}
if description:
    embed["description"] = description
if link:
    embed["url"] = link

return {"username": "authentik", "embeds": [embed]}
