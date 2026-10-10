"""
sections_statelessness_101.py — slide content for the STATELESSNESS 101 deck.

A gentle on-ramp to the STATELESSNESS COMPENDIUM (the 201 deck). Written for
a C++ developer who has not read the compendium and needs the vocabulary and
the core mechanism (RAII) before the deep material makes sense.

Same schema, same renderer (build-pptx.py builders) as the 201 deck's
sections_statelessness.py. No demo-cue slides here: the runnable demos live
with the compendium, and this deck does not claim them.

Each section dict:
  - num, label, title, tagline, divider_notes, slides[]
Slide kinds used here: content | content-code | stat-row

Human-edited prose; build-statelessness-101-pptx.py is the renderer.
"""
from pptx.dml.color import RGBColor
from pptx.util import Pt
from pptx.enum.text import PP_ALIGN


class C:
    ACCENT_CYAN    = RGBColor(0x00, 0xBC, 0xD4)
    ACCENT_BLUE    = RGBColor(0x1E, 0x6F, 0xC8)
    ACCENT_GREEN   = RGBColor(0x27, 0xAE, 0x60)
    ACCENT_RED     = RGBColor(0xE8, 0x48, 0x55)
    ACCENT_ORANGE  = RGBColor(0xF5, 0xA6, 0x23)
    ACCENT_PURPLE  = RGBColor(0x9B, 0x59, 0xB6)
    TEXT_DARK      = RGBColor(0x1A, 0x2B, 0x3C)
    TEXT_MUTED     = RGBColor(0x90, 0xA4, 0xAE)
    BG_CARD_LIGHT  = RGBColor(0xEC, 0xF0, 0xF1)
    BG_CARD_SOFT   = RGBColor(0xE0, 0xE8, 0xF0)


def para(text, size=Pt(16), bold=False, italic=False,
         color=C.TEXT_DARK, bullet=False, align=PP_ALIGN.LEFT,
         space_before=None):
    d = dict(text=text, size=size, bold=bold, italic=italic,
             color=color, bullet=bullet, align=align)
    if space_before is not None:
        d["space_before"] = space_before
    return d


def bullet(text, size=Pt(15)):
    return dict(text=text, size=size, bold=False, color=C.TEXT_DARK,
                bullet=True)


def heading(text, size=Pt(18), color=None):
    return dict(text=text, size=size, bold=True, color=color or C.TEXT_DARK)


SECTIONS = [

# ============================================================================
# §1 — Why statelessness matters for C++ services
# ============================================================================
{
    "num": 1,
    "label": "§1",
    "title": "Why statelessness matters for C++ services",
    "tagline": "A process that forgets everything it doesn't need to remember is a process you can kill without fear.",
    "divider_notes": (
        "Welcome. This is the on-ramp, not the deep dive. If you haven't read "
        "the statelessness compendium, start here. We're going to build the "
        "vocabulary and the one mechanism you need before the deeper material "
        "makes sense.\n\n"
        "The starting question: why does a C++ developer, who already knows "
        "RAII and the STL cold, need a whole talk about statelessness? "
        "Because the thing that breaks under containers isn't your C++. It's "
        "habits that were harmless on a dedicated box and become correctness "
        "bugs the moment an orchestrator can kill, replace, or multiply your "
        "process without asking."),
    "slides": [
        {
            "kind": "content",
            "title": "The problem with a service that remembers",
            "body": [
                heading("State creeps in quietly", color=C.ACCENT_RED),
                bullet("An in-memory cache keyed by session, filled the first time a user shows up"),
                bullet("A counter or rate limiter that assumes it has seen every prior request"),
                bullet("A background thread that opened a file on startup and never checks if it's still there"),
                para("None of this looks dangerous in a single-process test. "
                     "Every one of these becomes a bug the moment there's more "
                     "than one copy of the process, or the process restarts "
                     "mid-shift.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "Each of these three examples compiles fine, passes unit "
                "tests, and works perfectly in a demo with one instance and "
                "one developer hitting it. The session cache answers correctly "
                "as long as the same replica keeps serving the same user. The "
                "rate limiter is correct as long as there's exactly one copy "
                "counting. The background file handle is fine until the "
                "container restarts and the file it opened doesn't exist in "
                "the new one.\n\n"
                "None of these are C++ bugs. The language did exactly what it "
                "was told. They're state-placement bugs: data that needs to "
                "survive a restart, or needs to be shared across replicas, got "
                "put somewhere that neither survives nor is shared."),
        },
        {
            "kind": "content",
            "title": "What changes under an orchestrator",
            "body": [
                heading("The assumptions a dedicated box lets you get away with",
                        color=C.ACCENT_BLUE),
                bullet("Processes are disposable — the orchestrator restarts them routinely, not just on crash"),
                bullet("Replicas come and go — scaling up or down changes which processes exist, mid-traffic"),
                bullet("There is no \"the same instance\" — a load balancer has no memory of who it talked to last"),
                para("A habit that's harmless with one long-lived process "
                     "becomes a correctness bug across N short-lived, "
                     "interchangeable ones.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "This is the mental shift. On a dedicated box, the process is "
                "basically permanent: it starts once, maybe gets restarted "
                "during a deploy window you control, and there's exactly one "
                "of it. Under an orchestrator, none of that holds. Kubernetes "
                "or Nomad or whatever you're running will kill and restart "
                "your process for reasons that have nothing to do with your "
                "code: a node needs to drain, a rolling update is in "
                "progress, the autoscaler decided to add or remove replicas.\n\n"
                "The practical consequence: anything your process is the only "
                "copy of, is at risk of disappearing without warning. And "
                "anything you assumed was consistent across requests because "
                "they all hit 'your' process is wrong the moment there are two "
                "replicas, because the load balancer picks whichever one is "
                "free."),
        },
        {
            "kind": "stat-row",
            "title": "Four things worth memorizing before we go further",
            "stats": [
                ("Any", "replica should be able to answer any request —\nnone of them are special",
                 C.ACCENT_BLUE),
                ("0", "coordination required between replicas before the\norchestrator kills one of them",
                 C.ACCENT_GREEN),
                ("Routine", "restarts are, under an orchestrator — not\nincidents, not exceptional",
                 C.ACCENT_CYAN),
                ("1", "binary — stateless or not depends on what it\nholds and where, not how it's written",
                 C.ACCENT_PURPLE),
            ],
            "notes": (
                "Four framing numbers for today's session. Any replica "
                "answers any request: that's the interchangeability property "
                "we're aiming for. Zero coordination to kill one: that's the "
                "operational payoff, and it's what the orchestrator is relying "
                "on when it reschedules work. Restarts are routine, not "
                "incidents: if a restart loses data or breaks a client, that's "
                "a design gap, not bad luck. And the last one is the thesis "
                "of the whole on-ramp: it's one binary, and whether it's "
                "stateless is a property of where it keeps data, not a "
                "property you can read off the source code."),
        },
    ],
},

# ============================================================================
# §2 — Stateless deployment posture: kill, replace, replicate
# ============================================================================
{
    "num": 2,
    "label": "§2",
    "title": "Stateless deployment posture: kill, replace, replicate",
    "tagline": "The orchestrator's three verbs, and what each one assumes about your process.",
    "divider_notes": (
        "Deployment posture is the term for the contract between your "
        "process and the orchestrator. It's not about what your code does; "
        "it's about what the orchestrator is allowed to do to your process "
        "without asking permission first. Three verbs cover it: kill, "
        "replace, replicate."),
    "slides": [
        {
            "kind": "content",
            "title": "Kill",
            "body": [
                heading("The orchestrator can end your process at any time",
                        color=C.ACCENT_RED),
                bullet("A node needs to drain, a rolling update starts, the autoscaler decides to shrink"),
                bullet("Your process gets a termination signal, and after a grace period, no signal at all"),
                bullet("It does not negotiate: it does not wait for your in-flight state to be safe first"),
                para("The design requirement this creates: whatever happens, "
                     "nothing authoritative can be lost when the process "
                     "simply stops.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "Kill is the base case. It can happen for operational reasons "
                "that have nothing to do with your service being unhealthy: "
                "node maintenance, a deploy, a cost-driven scale-down. Your "
                "process gets a chance to shut down gracefully (a grace "
                "period after the first signal), but it does not get a vote "
                "on whether or when this happens.\n\n"
                "The compendium has a full document on graceful shutdown and "
                "health checks that goes into exactly how to use that grace "
                "period well. For now, the point is narrower: design so that "
                "a kill at a bad moment costs you a restart, never correctness."),
        },
        {
            "kind": "content",
            "title": "Replace",
            "body": [
                heading("A new replica starts from the same image, from zero",
                        color=C.ACCENT_ORANGE),
                bullet("It does not inherit anything the dead replica was holding in memory"),
                bullet("Startup has to be fast and self-sufficient — no dependency on the old process's state"),
                bullet("Anything the new replica needs, it has to be able to rebuild or fetch on its own"),
                para("This is where \"process scope\" earns its name: state "
                     "it's fine to rebuild from scratch every time the "
                     "process starts.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "Replace follows kill: the orchestrator doesn't just remove a "
                "replica, it typically starts a fresh one to take its place. "
                "That fresh one is a brand-new process. It has no memory of "
                "the one it's replacing — same binary, same image, zero "
                "shared state.\n\n"
                "This is the first hint of the scope vocabulary we're about "
                "to introduce properly: there's a category of state that's "
                "fine to lose on replace, because it's cheap to rebuild — "
                "thread pools, connection pools, parsed configuration. We'll "
                "call that process scope in the next section."),
        },
        {
            "kind": "content",
            "title": "Replicate",
            "body": [
                heading("Many identical copies, one traffic stream",
                        color=C.ACCENT_GREEN),
                bullet("2, 10, or 100 copies of the same process can be serving traffic at once"),
                bullet("A load balancer routes each request to whichever replica is free"),
                bullet("It does not try to send a user's requests back to \"their\" replica"),
                para("This only works if every replica is interchangeable — "
                     "which is exactly what statelessness means in practice.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "Replicate is what makes kill and replace survivable at "
                "scale: because there's more than one copy, losing one "
                "doesn't take the service down. But replicate only pays off "
                "if the replicas are actually interchangeable. If replica A "
                "remembers something replica B doesn't, a request routed to B "
                "gets a wrong or inconsistent answer — and the load balancer "
                "has no way to know it should have gone to A.\n\n"
                "Put the three together: kill means any replica can end at "
                "any time, replace means its successor starts from zero, and "
                "replicate means a request can land on any of them. "
                "Statelessness is simply the property that makes all three "
                "safe at once."),
        },
    ],
},

# ============================================================================
# §3 — Three scopes, briefly
# ============================================================================
{
    "num": 3,
    "label": "§3",
    "title": "Three scopes, briefly",
    "tagline": "Not all state is equal; where it lives decides whether a kill is safe.",
    "divider_notes": (
        "Three scopes of state show up everywhere in the compendium, so it's "
        "worth getting the shallow version right here. This section is "
        "deliberately brief — each of these gets a full document's worth of "
        "treatment in the 201 deck. The goal today is just to recognize the "
        "three buckets and know which one is dangerous to get wrong."),
    "slides": [
        {
            "kind": "content",
            "title": "Request scope",
            "body": [
                heading("Lives for exactly one call", color=C.ACCENT_CYAN),
                bullet("Created when the handler starts, destroyed when it returns"),
                bullet("Examples: a parsed request, a per-call buffer, a database transaction handle"),
                bullet("Nothing here should be referenced after the response has shipped"),
                para("If a kill happens mid-request, the one thing in flight "
                     "is the request itself — and the client can simply retry.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "Request scope is the easiest of the three because C++ "
                "already has a mechanism built for exactly this shape: a "
                "stack-allocated or scope-owned object whose lifetime matches "
                "the handler function. We'll make that concrete with RAII in "
                "the next section.\n\n"
                "The risk to watch for is a reference to request-scoped data "
                "escaping its scope — a pointer stashed in a process-scoped "
                "cache, a background task capturing something by reference. "
                "That's how request scope quietly turns into a lifetime bug."),
        },
        {
            "kind": "content",
            "title": "Process scope",
            "body": [
                heading("Lives for as long as the process runs", color=C.ACCENT_BLUE),
                bullet("Examples: a thread pool, a connection pool, parsed configuration"),
                bullet("Safe to lose on restart, as long as it's cheaply rebuildable from scratch"),
                bullet("Owned explicitly, typically assembled once at startup — not scattered as globals"),
                para("Losing process-scoped state costs you a restart, "
                     "nothing more, provided nothing in it was authoritative.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "Process scope is where a lot of legitimate, useful state "
                "lives: pools you don't want to rebuild per request, config "
                "you parsed once, maybe an in-memory cache that's purely a "
                "performance optimization. The compendium's document on "
                "process-scoped ownership goes deep on how to size and own "
                "this explicitly instead of letting it accrete as singletons.\n\n"
                "The one rule that keeps process scope safe: it has to be "
                "re-creatable. If losing it on restart would lose data a "
                "client cares about, it's not process scope, it's "
                "accidentally external state that forgot to leave the "
                "process."),
        },
        {
            "kind": "content",
            "title": "External state",
            "body": [
                heading("Lives outside the process entirely", color=C.ACCENT_PURPLE),
                bullet("Examples: the database, the cache tier, the message queue"),
                bullet("The only place authoritative data is allowed to live"),
                bullet("Reached over the network, with its own availability and consistency story"),
                para("The compendium calls this deploy-time scope and spends "
                     "a full document on reaching it safely — pools, "
                     "idempotency, the outbox pattern.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "External state is the answer to the question request scope "
                "and process scope both raise: where does data that has to "
                "survive a kill actually live? Outside the process, in "
                "something the orchestrator isn't managing as a disposable "
                "replica — a database, a durable queue, a distributed cache.\n\n"
                "This is also where the real engineering difficulty shows "
                "up, because reaching external state safely from a process "
                "that can die mid-call needs its own patterns: connection "
                "pooling with RAII checkout, idempotent writes, retry "
                "policies that don't double-charge a customer. That's the "
                "state externalization document in the compendium — this "
                "slide is the whole of what we cover today, the pointer is "
                "where to go deeper."),
        },
    ],
},

# ============================================================================
# §4 — RAII: the mechanism
# ============================================================================
{
    "num": 4,
    "label": "§4",
    "title": "RAII: the mechanism",
    "tagline": "A destructor that always runs is how C++ makes request scope a guarantee instead of a convention.",
    "divider_notes": (
        "Every scope so far has been a description of where state ought to "
        "live. RAII is the one piece of actual mechanism in this on-ramp: "
        "the C++ language feature that turns 'request scope' from a design "
        "intention into something the compiler enforces for you."),
    "slides": [
        {
            "kind": "content",
            "title": "What RAII actually buys you",
            "body": [
                heading("Bind a resource's lifetime to an object's scope",
                        color=C.ACCENT_GREEN),
                bullet("Acquire the resource in the constructor"),
                bullet("Release it in the destructor"),
                bullet("The compiler calls that destructor on every exit path — return, break, or an exception"),
                para("You don't write cleanup code at each exit point. You "
                     "write it once, and the language guarantees it runs.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "If you've used std::unique_ptr, std::lock_guard, or a "
                "std::fstream, you've already used RAII — this is nothing "
                "new as a C++ idiom. What's new here is the framing: RAII "
                "isn't just a memory-safety trick, it's the mechanism that "
                "makes request scope real.\n\n"
                "A request handler can early-return on a validation failure, "
                "throw on a downstream error, or run to completion normally. "
                "Without RAII you'd need cleanup code on every one of those "
                "paths, and it's easy to miss one. With RAII, the destructor "
                "runs regardless of which path was taken, because it's tied "
                "to the object going out of scope, not to a particular line "
                "of code executing."),
        },
        {
            "kind": "content-code",
            "title": "A request-scoped object, start to finish",
            "body": [
                heading("The shape you'll see throughout the compendium",
                        color=C.ACCENT_BLUE),
                bullet("The pooled connection is acquired once, in the constructor"),
                bullet("Every exit from handle() destroys ctx — success, early return, or exception"),
                bullet("The connection returns to the pool exactly once, no matter which path was taken"),
            ],
            "code": (
                "class RequestContext {\n"
                "public:\n"
                "    explicit RequestContext(ConnectionPool& pool)\n"
                "        : conn_(pool.acquire()) {}\n"
                "\n"
                "    Connection& conn() { return conn_; }\n"
                "\n"
                "private:\n"
                "    PooledConnection conn_;  // returns to the pool\n"
                "                             // when this is destroyed\n"
                "};\n"
                "\n"
                "void handle(ConnectionPool& pool, const Request& req) {\n"
                "    RequestContext ctx(pool);\n"
                "\n"
                "    if (!valid(req)) return;        // ctx destructs here\n"
                "    ctx.conn().execute(build(req));  // might throw\n"
                "\n"
                "}  // ... or ctx destructs here, on the normal path\n"
            ),
            "notes": (
                "Walk through this slowly. RequestContext owns one thing: a "
                "pooled connection, acquired in the constructor. It doesn't "
                "have a close() or release() method that handle() has to "
                "remember to call — there's nothing to remember.\n\n"
                "Look at the three ways handle() can end: an early return on "
                "invalid input, an exception thrown from execute(), or a "
                "normal fall-through at the end. All three destroy ctx. All "
                "three return the connection to the pool exactly once. This "
                "is the entire trick: request scope is enforced by the "
                "compiler's own stack-unwinding machinery, not by developer "
                "discipline at every call site.\n\n"
                "The compendium's RAII document builds this pattern out "
                "further — layering in request-scoped memory arenas, "
                "distributed tracing spans, and the full exception-safety "
                "guarantee taxonomy. This is the seed of all of that."),
        },
        {
            "kind": "content",
            "title": "Why this is the mechanism, not just a style",
            "body": [
                heading("Enforceable beats aspirational", color=C.ACCENT_RED),
                bullet("A naming convention or a code-review checklist can be skipped under deadline pressure"),
                bullet("A destructor that the compiler calls on every path cannot be skipped"),
                bullet("This is what makes \"nothing outlives the request\" a property you can rely on, not a hope"),
                para("RAII is why C++ is a good fit for stateless "
                     "services, despite having no garbage collector to lean on.",
                     size=Pt(15), italic=True, color=C.TEXT_MUTED),
            ],
            "notes": (
                "This is the bridge slide back to the bigger picture. "
                "Languages with a garbage collector get memory safety "
                "automatically but don't get deterministic, scope-tied "
                "cleanup — a connection or a file handle held by a finalizer "
                "can linger arbitrarily long after you're done with it. C++ "
                "trades that automatic memory safety for deterministic "
                "destruction, and that's exactly the guarantee "
                "request scope needs.\n\n"
                "Hold onto this one idea past today: statelessness is a "
                "deployment posture, and RAII is the C++-specific mechanism "
                "that makes the request-scope half of that posture "
                "enforceable instead of aspirational."),
        },
    ],
},

# ============================================================================
# §5 — Where the compendium goes deeper
# ============================================================================
{
    "num": 5,
    "label": "§5",
    "title": "Where the compendium goes deeper",
    "tagline": "This was the on-ramp. Eleven documents build the rest of the machine.",
    "divider_notes": (
        "That's the on-ramp: why statelessness matters, the three verbs the "
        "orchestrator uses against your process, the three scopes of state, "
        "and RAII as the mechanism that makes request scope real. Everything "
        "from here is the compendium's job, and this last section is a map "
        "of where each loose end gets picked back up."),
    "slides": [
        {
            "kind": "content",
            "title": "What's next, by concept",
            "body": [
                heading("The compendium, mapped to what we touched today",
                        color=C.ACCENT_CYAN),
                bullet("Request memory without per-request allocation — PMR arenas layered onto RAII"),
                bullet("Process-scoped ownership done well — composition roots, dependency injection over singletons"),
                bullet("Threading under a real CPU quota — why hardware_concurrency() lies to you in a container"),
                bullet("Reaching external state safely — pooled connections, the outbox pattern, idempotency, deadlines"),
                bullet("The ephemeral filesystem, health checks, graceful shutdown, and a full gRPC end-to-end example that composes all of it"),
            ],
            "notes": (
                "Everything on this slide is a direct extension of something "
                "we introduced today, not new material out of nowhere. PMR "
                "builds on RAII's acquire-release shape to give request-"
                "scoped memory without a per-request heap allocation. "
                "Process-scoped ownership builds on the process-scope "
                "definition with a concrete pattern for assembling it at "
                "startup. State externalization is the full engineering "
                "answer to the external-state scope we only named today. And "
                "the gRPC end-to-end example shows all three scopes, RAII, PMR, and "
                "externalization composed into one real service.\n\n"
                "Read the documents in order if you want the full arc; each "
                "one stands alone if you already know roughly where you need "
                "depth. Every pattern in the compendium has a runnable Docker "
                "demo, host-verified end to end — this on-ramp doesn't carry "
                "its own demos, the compendium's do."),
        },
        {
            "kind": "content",
            "title": "If you remember one thing",
            "body": [
                heading("Statelessness is earned, not declared", color=C.ACCENT_GREEN),
                para("It's a deployment posture: a property of where a "
                     "service keeps its data, not something you can read off "
                     "the source code.",
                     size=Pt(17)),
                para("RAII is the C++ mechanism that makes the request-scope "
                     "half of that posture enforceable rather than "
                     "aspirational.",
                     size=Pt(17), space_before=Pt(12)),
                para("Everything else in the compendium is about getting the "
                     "other two scopes — process and external — right.",
                     size=Pt(17), color=C.ACCENT_BLUE, space_before=Pt(12)),
            ],
            "notes": (
                "If none of the detail sticks, this is the sentence to keep: "
                "the same C++ binary can be stateless or stateful depending "
                "only on where it keeps state, and RAII is the tool that "
                "makes the request-scope part of that trustworthy rather "
                "than a matter of discipline.\n\n"
                "From here, go to the compendium. Start with the deployment "
                "posture document if you want the fuller version of today's "
                "opening, or jump straight to RAII if you want the deep "
                "version of what we just showed. Thanks for starting here."),
        },
    ],
},

]
