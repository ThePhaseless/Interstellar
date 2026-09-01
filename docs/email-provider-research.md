# Cheap hosted email with a custom domain — provider comparison

**Date of observation:** 2026-08-01 (all prices/limits as seen on the official pages on this date)
**Scenario:** migrating several **private** mailboxes to a fully managed host for a custom domain (e.g. `nerine.dev`), using **IMAP/SMTP clients**, already sending via **Oracle Cloud Infrastructure Email Delivery (free SMTP relay)**. No self-hosting.

> Method: every price/limit below was read from the linked official page on 2026-08-01 (or as dated). Where a page is geo-gated (serves a local currency) that is stated explicitly. No AI-generated listicles were used. `[INFERENCE]` marks a claim derived from observed facts rather than a quote.

---

## At a glance

| Provider | Price (observed) | What it buys | Mailboxes | Storage | IMAP/SMTP clients | External SMTP (Oracle) from client | Migration tool |
|---|---|---|---|---|---|---|---|
| **Zoho Mail Lite** | $1/user/mo billed annually (5 GB), $1.25 (10 GB) | per user, any number | per-user | 5–10 GB/user | ✅ paid plans only (free plan: **no** IMAP/POP) | ✅ allowed (even has Outbound Gateway) | ✅ built-in IMAP migration (admin) |
| **Migadu Micro / Mini** | $19/yr (Micro) · $90/yr (Mini) | flat per account, **unlimited mailboxes** | unlimited | 5 GB / 30 GB (soft) | ✅ standard IMAP/POP/SMTP | not documented (client-side free; their SMTP restricts From) | ❌ none found (manual) |
| **Purelymail** | $10/yr flat (simple pricing) | flat per account, no hard limits | unlimited | no hard limit (soft) | ✅ standard IMAP/SMTP | not documented (no restriction found) | ❌ none found (manual) |
| **Fastmail Standard / Family** | $5/user/mo annual ($60/yr); Family $11/mo annual ($132/yr, up to 6 users) | per user or flat family | per user (≤6 on Family) | 50 GB mail +10 GB file | ✅ Standard+ (Basic: web/app) | not documented (client-side) | ✅ built-in import (Settings → Migration → Import) |
| **Proton Mail Plus** | US$3.99/mo annual ($47.88/yr) or $4.99 monthly | **1 user** per plan | 1 per plan | 15 GB | ⚠️ Bridge only, desktop, paid | ❌ not supported (all outbound via Proton) | ✅ Easy Switch |
| **iCloud+ Custom Domain** | from $0.99/mo (US 50 GB tier) | 1 iCloud+ account | **≤3 addresses per domain** (≤5 domains) | 50 GB+ (iCloud shared) | ✅ IMAP/SMTP in any client | not documented (client-side) | ✅ import from previous provider |
| **Mailbox.org Standard** | €3/mo billed annually (new from 15 Jul 2026); ≈€30/yr with annual discount | per mailbox (family: up to 10 members) | per mailbox (≤10 per family acct) | 20 GB mail +10 GB Drive | ✅ IMAP/POP3 | not documented (client-side) | ✅ audriga relocation (Standard+) |
| **Google Workspace Starter** (baseline) | PLN 31.50/user/mo annual observed (official page geo-gated); US list commonly $7/user/mo annual | per user | per user | 30 GB pooled | ✅ IMAP/SMTP | ⚠️ Gmail "Send as" for third-party addresses ends Jan 2027; desktop clients fine | ✅ Google Workspace Migrate (Standard+), Data Migration |
| **Microsoft 365 Business Basic** (baseline) | $7.00/user/mo paid yearly | per user | per user | 100 GB primary +50 GB archive | ✅ (Outlook/IMAP) | client-side, no restriction found | ✅ Exchange admin migration tools |
| **Cloudflare Email Routing** ($0 option) | **$0** | inbound forwarding only | n/a (forward) | n/a (to a mailbox) | ❌ **no IMAP/SMTP on your domain** | n/a — you *must* use Oracle (or another sender) | ❌ none (it's a forwarder) |

---

## 0. Gmail → Zoho migration specifics (verified on Zoho docs, 2026-08-01)

Two official paths (https://www.zoho.com/mail/help/adminconsole/gsuite-to-zoho-mail-migration.html and https://www.zoho.com/mail/help/adminconsole/gmail-to-zoho-imap-migration.html, both last updated 2026-07-29):

- **One-click Google Workspace migration** — only for Google Workspace accounts (business). Requires Workspace super admin + service account JSON/P12 key. Migrates **mail + contacts + calendar** in one tool. Personal free @gmail.com accounts cannot use this path.
- **IMAP migration** — works for personal Gmail: Admin Console → Data Migration → IMAP → `imap.gmail.com:993` SSL. Requires IMAP enabled in Gmail + **16-digit App Password** (Google deprecated "less secure apps"; the doc explicitly says App Password). Migrates **mail only** — no contacts/calendar. Options: folder exclusions, date ranges, "Mark Important/Starred as Tag", parallel connection limit, pause at 80%/95% storage.
- **Gmail labels become folders, and multi-label emails are duplicated per label**: a 10 MB email with 3 labels migrates 4 times = 30 MB (Zoho's own example). Bloat trap on the 5 GB Lite plan — exclude redundant folders (e.g. `Important`, which duplicates Inbox), minimize labels before migrating. Migration auto-pauses at the storage threshold; resume after freeing space or buying more.
- **Not migrated by the tool**: contacts + calendar for personal Gmail (manual: Google Contacts → vCard/CSV → Zoho import; Google Calendar → ICS → Zoho Calendar import), Gmail filters (recreate as Zoho filters), the Google account itself (keep it for YouTube/Play/Android — set Gmail forwarding + vacation responder during cutover instead of deleting).
- Source passwords must stay unchanged until the migration finishes.

## 1. Zoho Mail

**Official pricing:** https://www.zoho.com/mail/zohomail-pricing.html (observed 2026-08-01; USD figures from the page's embedded offer data)

| Plan | Price | Includes |
|---|---|---|
| Mail Free | $0, forever, no credit card | up to **5 users**, 5 GB/user, 1 custom domain, mobile app — **"IMAP/POP/ActiveSync not included"** (per pricing page); free tier only in **select regions** (page meta/notes) |
| Mail Lite 5 GB | **$1/user/mo, billed annually** (no monthly option) | custom domain, 5 GB/user, IMAP/POP/SMTP |
| Mail Lite 10 GB | $1.25/user/mo annual | same, 10 GB/user |
| Workplace Standard | $3/user/mo annual | 30 GB mail/user + shared file storage |
| Mail Premium | $4/user/mo annual | 50 GB mail + 50 GB retention/user |
| Workplace Professional | $6/user/mo annual | 100 GB mail/user |

- **IMAP/SMTP:** paid custom-domain accounts use `imappro.zoho.com:993` / `smtppro.zoho.com:465`(SSL) or `587`(TLS); free-org accounts use `imap.zoho.com` / `smtp.zoho.com`. Requires enabling IMAP; app-specific password with 2FA. Docs: https://www.zoho.com/mail/help/imap-access.html and https://www.zoho.com/mail/help/zoho-smtp.html. **The free plan has no IMAP/POP access** — "For newly signed-up users (Free plan), the IMAP Access feature will not be available" (IMAP help page). So desktop-client migration requires a paid plan.
- **External SMTP (Oracle) from a client:** allowed. Zoho documents its own SMTP for clients (above) and even ships an admin **Outbound Gateway** that relays outgoing mail through another SMTP server (https://www.zoho.com/mail/help/adminconsole/email-routing.html). Nothing in Zoho docs forbids pointing a client's outgoing server at Oracle; "Relaying Disallowed" errors only apply to From addresses that don't match the account on Zoho's own SMTP. SPF/DKIM: you add Zoho's DKIM key for the domain; Oracle's SPF/DKIM covers Oracle-sent mail (include both in SPF).
- **Catch-all:** yes — Email Routing lets you forward mail for unknown recipients to a designated user (https://www.zoho.com/mail/help/adminconsole/email-routing.html).
- **Migration:** built-in IMAP migration in the Admin Console (**Data Migration → Start Migration**), any IMAP source (Gmail/Yahoo/Office 365/other), plus the Zoho Email Migration Wizard. https://www.zoho.com/mail/help/adminconsole/migration.html (this URL served Spanish from our location; English equivalent exists under the same path).
- **Trial:** 15 days, no credit card, on any paid plan (https://www.zoho.com/mail/help/adminconsole/subscription.html).
- **Caveats:** free tier is regional and has no IMAP (you must pay for client access); per-user pricing scales with mailbox count ($60/yr for 5× Lite); paid plans are ad-free; Zoho is a large SaaS vendor (privacy considerations apply).

---

## 2. Migadu

**Official pricing:** https://www.migadu.com/pricing/ (observed 2026-08-01). Flat per-**account** pricing: "An account may have unlimited mailboxes and addresses… no additional cost" for extra addresses.

| Plan | Price | In/day | Out/day | Storage (soft) |
|---|---|---|---|---|
| **Micro** | **$19/yr** (no monthly) | 200 | 20 | 5 GB |
| **Mini** | $9/mo or **$90/yr** | 1,000 | 100 | 30 GB |
| Standard | $29/mo or $290/yr | 3,000 | 500 | 100 GB |
| Maxi | $99/mo or $990/yr | 10,000 | 2,000 | 500 GB |

- **Limits:** unlimited mailboxes/addresses/domains on every plan (domains on Micro are "almost unlimited" — soft anti-abuse rule). **Storage is soft** ("Mails will never bounce back because of full storage"). Over-limit behavior: 25% tolerance, then deferring/rejecting. The old free plan is gone; Micro replaced it.
- **IMAP/SMTP:** `imap.migadu.com:993`, `pop.migadu.com:995`, `smtp.migadu.com:465` (plain-password auth). "Any standards-oriented email client will work" (https://www.migadu.com/support and https://migadu.com/guides).
- **Catch-all:** yes — "You can configure a catchall for improperly addressed messages" (https://www.migadu.com/support).
- **External SMTP (Oracle) from a client:** their own SMTP requires that the From address be hosted on your Migadu domain ("You cannot send as an address not hosted by us", https://www.migadu.com/support). Whether pointing a client's *outgoing server* at Oracle (with Oracle SMTP credentials, From = your domain address) is permitted is **not documented**; nothing found that forbids it, and it is a purely client-side configuration. `[INFERENCE]` For deliverability you'd keep SPF including both Migadu and Oracle, and use Oracle's DKIM for Oracle-sent mail.
- **Migration:** no built-in import tool found — manual migration (IMAP drag-and-drop / client tools).
- **Trial/refund:** "Try for Free — No credit card required"; 100% refund within 14 days (https://www.migadu.com/pricing/).
- **Caveats:** usage-metered (daily in/out quotas across the whole account — Micro's 20 out/day is tight for several active mailboxes; Mini is the realistic floor); email/ticket support only; Swiss-ish indie, "guarding your data" positioning; no phone/chat.

---

## 3. Purelymail

**Official pricing:** https://purelymail.com/pricing (observed 2026-08-01).

- **Simple pricing: $10/year flat.** "There are no hard limits. Not on users, custom domains, storage, or anything else." Soft limits: heavy users are moved to **Advanced pricing** (pay-per-use): storage $0.56/compressed GB/yr, account fee $4/yr, receive $0.03/1,000 + $0.04/GB, send $0.23/1,000 (external) + $0.18/GB; **custom domains are free, no per-user charge on your own domain** (https://purelymail.com/advancedpricing).
- **Sending rate limit:** ~3,000 external messages/day (300 at once) on the account (https://purelymail.com/docs/faq).
- **IMAP/SMTP:** standard IMAP with any client; note Apple's iOS push (IMAP IDLE) limitation, and that IMAP can be slow on very large mailboxes (FAQ).
- **Catch-all / routing:** yes — account routing rules include a **catch-all rule**, redirect to external addresses, and symbolic subaddressing (`user+tag@`); no per-user charge for routing-only users (https://purelymail.com/docs/routing).
- **External SMTP (Oracle) from a client:** **not documented** — no policy found either way; the service even supports third-party MX antispam in front (whitelisted services), suggesting a permissive posture. Client-side SMTP choice is not restricted. `[INFERENCE]`
- **Migration:** no built-in import tool documented — manual (IMAP client drag-and-drop).
- **Trial:** trial accounts exist with full features but very low external-send limits (FAQ). Refund policy: not documented.
- **Caveats:** micro-vendor — US (Delaware) company, servers in AWS us-east-1 (FAQ); no wildcard subdomains; barebones support; email aliases via routing rules rather than a dedicated alias feature.

---

## 4. Fastmail

**Official pricing:** https://www.fastmail.com/pricing/ (USD, observed 2026-08-01; prices extracted from the page, monthly vs annual and multi-year):

| Plan | Monthly | Billed annually | Storage (mail + file) |
|---|---|---|---|
| Basic | $4/user/mo | $3/user/mo ($36/yr) | 5 GB + 1 GB |
| **Standard** (individual) | $6/mo | **$5/mo ($60/yr)** | 50 GB + 10 GB |
| Professional | $12/mo | $9/mo ($108/yr) | 100 GB + 50 GB |
| Duo (2 users) | $10/mo | $8/mo ($96/yr) | 50 + 10 GB per user |
| **Family (up to 6 users)** | $14/mo | **$11/mo ($132/yr)** | 50 + 10 GB per user |

(24-month ≈ $4.75, 36-month ≈ $4.67 per user/mo on Standard; similar discounts on others.)
- **Limits:** aliases **600 + 15 per extra user** on all plans; domains 100 + 1 per user on non-Basic plans (Basic plans effectively can't host custom domains — "at least one admin… must be on a non-Basic subscription plan"). Catch-all via wildcard `*@domain` aliases and mirrored domains. Sending limits: Standard 8,000/day (2 GB); trial accounts capped at 120/day. Source: https://www.fastmail.help/hc/en-us/articles/1500000277382-Account-limits and https://www.fastmail.help/hc/en-us/articles/360058753394-Custom-domains-with-Fastmail.
- **IMAP/SMTP:** "With the Standard or Professional plan, you can also use Fastmail with other email apps, such as Outlook, iPhone Mail, or Thunderbird" (pricing-page FAQ); Basic is web/app-oriented.
- **External SMTP (Oracle) from a client:** **not documented** — Fastmail documents its own SMTP; no doc found permitting or forbidding an external relay. Client-side SMTP choice is not technically restricted by Fastmail. `[INFERENCE]`
- **Migration:** built-in **import tool** (Settings → Migration → Import), including a generic "Other (IMAP/CardDAV/CalDAV)" option for any provider (https://www.fastmail.help/hc/en-us/articles/360060590593-Migrate-to-Fastmail-from-another-provider).
- **Trial:** free trial exists; trial accounts limited to 120 outgoing msgs/day until paid (Account-limits article).
- **Caveats:** no ads/tracking, privacy positioning; per-user pricing on individual plans (Family flat $132/yr for up to 6 users is the sweet spot for several mailboxes); Australia/US-based.

---

## 5. Proton Mail (Plus / Unlimited / Business)

**Official pricing:** https://proton.me/mail/pricing (page geo-served PLN — we observed Mail Plus PLN 9.99/mo annual, Unlimited PLN 24.99/mo annual); USD confirmed at the official signup checkout (account.proton.me, USD, 2026-08-01):

- **Mail Plus:** **US$3.99/mo billed annually (US$47.88/yr)** or $4.99/mo monthly. 15 GB storage, **1 user**, 10 addresses/aliases, **1 custom domain**, 10 hide-my-email aliases.
- **Proton Unlimited:** **US$9.99/mo annual ($119.88/yr)** or $12.99 monthly. 500 GB, 1 user, **3 custom domains**, unlimited aliases + VPN/Drive/Pass.
- Free plan: 1 GB, 1 user, 1 address, **no custom domain**.
- Business (Mail Essentials / Workspace tiers): pricing not verifiable on the official page from this location (geo-gated); commonly quoted $6.99/user/mo annual for Mail Essentials `[INFERENCE — not directly observed]`.
- **IMAP/SMTP — Bridge caveat:** third-party clients need **Proton Mail Bridge** (desktop only: macOS/Windows/Linux, **no mobile**), paid plans only, no POP3. "Bridge manages both the incoming and outgoing server connections… send email securely through Proton Mail." Business plans additionally offer SMTP Submission. https://proton.me/support/imap-smtp-and-pop3-setup
- **External SMTP (Oracle):** **not supported** — outgoing always goes through Proton (Bridge exposes a local SMTP that forwards to Proton). Your Oracle relay cannot be used for Proton-hosted addresses in the normal Bridge/desktop flow.
- **Catch-all:** yes — per-domain catch-all in admin settings (https://proton.me/support/catch-all).
- **Migration:** Easy Switch import assistant (emails/calendar/contacts) included on paid plans (pricing page).
- **Trial/refund:** 30-day money-back guarantee (pricing page); free tier exists.
- **Caveats:** E2E encryption is the point (zero-access); **per-plan single-user** — several private mailboxes means several Mail Plus plans or a Duo/Family/Unlimited/business plan; Bridge must run on every desktop; poor fit for someone who already runs an external SMTP relay.

---

## 6. iCloud+ Custom Email Domain

**Official docs:** https://support.apple.com/en-us/102540 (limits) · https://support.apple.com/en-us/108047 (pricing) · https://support.apple.com/en-us/102525 (server settings) · https://support.apple.com/guide/icloud/allow-all-incoming-emails-mm9e3ee0680f/icloud (catch-all)

- **Price:** iCloud+ from **US$0.99/mo** (50 GB tier; 200 GB $2.99, 2 TB $9.99, 6 TB $29.99, 12 TB $59.99 — US prices, 2026-08-01). Custom Email Domain is included on **every** iCloud+ tier.
- **Limits:** **up to 5 custom domains, up to 3 personalized addresses per domain**; share a domain with up to 5 other people (Family Sharing or invited). Requires iCloud+ subscription, 2FA, and an existing primary iCloud Mail address.
- **Setup:** add MX + SPF + DKIM records at your DNS provider (Apple walks you through verification); no registrar/DNS lock-in.
- **Catch-all:** yes — "Allow all incoming messages" per domain (guide above).
- **IMAP/SMTP:** iCloud Mail works with standard IMAP/SMTP clients: `imap.mail.me.com:993` (SSL), `smtp.mail.me.com:587` (SSL/TLS), app-specific passwords; **no POP**. Your custom-domain address is usable in the same iCloud inbox (https://support.apple.com/en-us/102525).
- **External SMTP (Oracle):** not documented as restricted — iCloud documents only its own servers; nothing found forbidding a client's SMTP pointing at Oracle. Note Apple requires its DKIM record for the domain (which stays valid regardless of sender). `[INFERENCE]`
- **Migration:** yes — import existing messages from your previous provider for a custom domain (https://support.apple.com/en-us/102061).
- **Caveats:** the **3 addresses/domain cap** is the dealbreaker for "several private accounts" on one domain (works only if you split across up to 5 domains); inbox is shared with your @icloud.com address; strongly Apple-ecosystem flavored (web/desktop/mobile Apple apps first-class).

---

## 7. Mailbox.org

**Official pricing:** https://mailbox.org/en/prices/ and plan-change announcement https://mailbox.org/en/news/plan-adjustment-2026/ (observed 2026-08-01; new prices apply to new customers from 15 Jul 2026, existing from 1 Sep 2026; storage was doubled in the same change):

| Plan | Price | Mail storage | Aliases @yourdomain | Notes |
|---|---|---|---|---|
| Light | €1/mo (min €12 deposit) | 2 GB | — | **custom domains only in family accounts**; 3 aliases @mailbox.org |
| **Standard** (private) | **€3/mo billed annually** (≈€30/yr with "12 for 10" discount) | 20 GB | 50 | custom domains ✅, IMAP/POP3 ✅, audriga relocation ✅, family accounts up to 10 users |
| Premium (private) | €9/mo annually | 50 GB | 250 | + 100 GB Drive |
| Business Standard / Premium | €4 / €12 net per mo (from 1 Sep 2026) | 20 / 50 GB | 50 / 250 | |

- **IMAP/SMTP:** `imap.mailbox.org:993`, `pop3.mailbox.org:995`, `smtp.mailbox.org:465` (SSL/TLS; 587 STARTTLS) (https://kb.mailbox.org/en/private/e-mail/e-mail-configuration).
- **Catch-all:** yes (https://kb.mailbox.org/en/private/custom-domains/use-your-own-domain-with-catch-all).
- **External SMTP (Oracle):** not documented; no restriction found; client-side SMTP choice is free. `[INFERENCE]`
- **Migration:** **audriga** automated relocation (email, calendar, contacts, cloud files) included on Standard/Premium (prices page), plus migration guides (https://mailbox.org/en/move-mailbox-migrate-your-emails-securely/).
- **Trial:** 30 days free on any plan (homepage and prices FAQ).
- **Caveats:** German data centres, GDPR/ISO 27001/BSI C5; the Light plan **cannot host a custom domain** (family accounts only), so the entry point for this use case is Standard; prepaid credit model (refund not possible — pay only what you'll use); EU-focused billing.

---

## 8. Baselines (reference only)

### Google Workspace — Starter (formerly Business Starter)
- Official page: https://workspace.google.com/pricing — **geo-gated**: from this location it served PLN 31.50/user/mo billed annually for "Starter" (30 GB pooled storage, custom domain, 14-day trial; new 2026 lineup renamed Starter/Standard/Plus with Gemini included). The US list price could not be viewed from this network; multiple independent sources (incl. Google-authorized resellers) list **$7/user/mo annual / $8.40 flexible** `[INFERENCE — corroborated by resellers, not directly observed]`.
- **External SMTP:** Gmail's "Send as" supports adding an address with a third-party SMTP server (https://support.google.com/mail/answer/22370) — **but Google announced that "Send as" for third-party email addresses ends in January 2027** (Workspace aliases unaffected). Desktop clients (Outlook/Thunderbird) can use Oracle SMTP directly without restriction.
- Migration: Google Workspace Migrate (Standard+), Data Migration service.

### Microsoft 365 Business Basic
- Official page: https://www.microsoft.com/en-us/microsoft-365/business/microsoft-365-plans-and-pricing — **$7.00/user/mo paid yearly** (annual; a promo "no Teams" variant was shown at $5.40; Business Standard with Copilot $23.50, Premium $32.00). 100 GB primary + 50 GB archive mailbox, 1 TB OneDrive, web/mobile Office apps, 1-month free trial.
- External SMTP: no restriction documented for desktop clients (Outlook supports per-account outgoing servers); Exchange admin has built-in cutover/staged migration tools.
- Note: 2026 lineup bundles Copilot into some tiers — check the page at purchase time.

---

## 9. The $0 option — Cloudflare Email Routing (+ your existing Oracle SMTP)

**Official docs:** https://developers.cloudflare.com/email-service/ (overview) · pricing https://developers.cloudflare.com/email-service/platform/pricing/ · limits https://developers.cloudflare.com/email-service/platform/limits/ (observed 2026-08-01)

- **Price: $0.** Email Routing (inbound) is available on **Workers Free and Paid** plans, inbound **unlimited**.
- **What it does:** forwards mail for your domain to verified destination addresses (e.g. an existing Gmail/Outlook/other mailbox) or Workers. **No IMAP/POP/SMTP on your own domain** — there is no mailbox at `you@nerine.dev`; the mail lands in whatever mailbox you forward to (that mailbox's provider supplies IMAP).
- **Sending:** Email Routing does **not** send from your domain. Outbound ("Email Sending", beta) exists only on **Workers Paid** ($5/mo, 3,000 msgs/mo included, then $0.35/1,000). For this user, **Oracle Email Delivery remains the sender** — a perfect pairing, and exactly what the docs imply (route in via Cloudflare, send out via a dedicated ESP). Oracle's Always Free tier is **3,000 emails/month free** (https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm — "you can send 3000 emails for free per month").
- **Limits:** 200 routing rules per domain, **200 destination addresses per account** (across domains), inbound 25 MiB; 50 recipients/email outbound on Email Sending (https://developers.cloudflare.com/email-service/platform/limits/).
- **Catch-all:** yes — catch-all routing rules supported.
- **Authentication:** you set SPF/DKIM/DMARC at Cloudflare for the domain; Oracle-sent mail uses Oracle's SPF/DKIM (add both SPF includes; keep DKIM for both senders valid).
- **Caveats:** forwarding-only (no storage, no search on your own domain, no Sent folder at your domain unless the destination mailbox handles it); forwarding can break SPF/DKIM alignment unless the destination provider handles it (known email-forwarding wrinkle, not unique to Cloudflare); you still need a real mailbox somewhere for IMAP.

---

## Recommendation (for this user: 2–5 private mailboxes, cheap, IMAP clients, Oracle SMTP already in place, no self-hosting)

Ranked for total yearly cost at ~5 mailboxes, IMAP access, migration effort, and Oracle-as-outgoing-relay viability:

1. **Zoho Mail Lite ($1/user/mo annual → $60/yr for 5 mailboxes).** The best overall: real IMAP/SMTP on the paid tier, **built-in IMAP migration** from the current provider (lowest migration effort of the cheap options), catch-all, admin console, 15-day no-card trial, and no restriction on keeping Oracle as the outgoing relay (they even document an Outbound Gateway). Caveat: the free tier has **no IMAP**, so this use case requires the paid Lite plan.

2. **Purelymail ($10/yr flat, unlimited mailboxes).** Cheapest realistic option by far; no hard limits on users/domains/storage; standard IMAP/SMTP; catch-all + flexible routing; Oracle SMTP from clients is unrestricted (not documented otherwise). Caveats: no built-in migration tool (manual drag-and-drop), micro-vendor (Delaware/US, AWS us-east-1), support is minimal.

3. **Migadu Mini ($90/yr flat, unlimited mailboxes) — or Micro ($19/yr) if volume is light.** Flat account pricing makes the mailbox count irrelevant; mature, privacy-friendly, catch-all, standard IMAP/SMTP, 14-day refund. Micro's 20 out/day and 200 in/day quotas are tight for several active private mailboxes, so Mini is the realistic pick. No built-in migration tool.

**Honorable mentions / why not:**
- **Fastmail Family ($132/yr, up to 6 users, 50 GB each)** — the polished pick: excellent built-in import tool, wildcard-alias catch-all, IMAP on Standard+. ~$26/mailbox/yr at 5 mailboxes; only matters if you want maximum polish over cost.
- **iCloud+ Custom Domain ($12/yr)** — cheapest of all, but the **3-addresses-per-domain cap** makes 5 private accounts awkward (needs 2+ domains), and it's Apple-centric.
- **Mailbox.org Standard (≈€30/yr annual with discount; family accounts up to 10 users)** — strong EU/GDPR option with audriga migration, but Standard is the entry tier (Light can't host custom domains).
- **Proton** — poor fit: per-user plans ($47.88/yr per mailbox × N), Bridge is desktop-only, and **Oracle as outgoing relay is not supported**. Choose it only if E2E encryption is a hard requirement.
- **Google Workspace / Microsoft 365** — fine but ~$84–420/yr for 5 mailboxes; keep as baselines. Note Gmail's "Send as" for third-party addresses ends Jan 2027.

**Bottom line:** keep Oracle Email Delivery as the sender in every case (it is, at minimum, compatible with all of the above; only Proton structurally excludes it), point MX/SPF/DKIM at whichever host you choose, and pick Zoho Lite if migration tooling matters most, Purelymail if raw price matters most, or Migadu Mini if you want flat pricing independent of mailbox count.
