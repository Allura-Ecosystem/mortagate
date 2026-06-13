import { PageHeader } from "@/components/PageHeader";
import { CURRENT_ROLE, CURRENT_USER, ALL_ROLES, describeRole } from "@/lib/roles";
import { describeTransitions } from "@/lib/commands";

// Derived, not hand-typed: each role's plain-language capability list comes
// straight from the permission MATRIX (via describeRole), so this view cannot
// disagree with what the app actually enforces.
const ROLE_ROWS = ALL_ROLES.map((role) => ({ role, can: describeRole(role) }));

// Derived, not hand-typed: the rows below come straight from the transition
// graph + role matrix the app actually enforces, so this view cannot drift.
const STATE_FLOW = describeTransitions();

// Sentence-case the joined capability list (first letter up, trailing period).
function capabilitySentence(caps: string[]): string {
  if (caps.length === 0) return "No actions.";
  const joined = caps.join(", ");
  return joined.charAt(0).toUpperCase() + joined.slice(1) + ".";
}

export default function AdminPage() {
  return (
    <main className="p-8">
      <PageHeader
        title="Admin"
        subtitle="Who can do what, and how a case is allowed to move. These rules are enforced everywhere in the app."
      />

      <div className="mt-4 inline-flex items-center gap-2 rounded-full border border-line bg-white px-4 py-2 text-[13px]">
        <span className="text-muted">Signed in as</span>
        <span className="font-semibold text-ink">{CURRENT_USER}</span>
        <span className="rounded-full bg-peach px-2.5 py-0.5 text-[12px] font-semibold text-chip-amber-fg">
          {CURRENT_ROLE}
        </span>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <section className="rounded-[18px] border border-line bg-white p-6">
          <h2 className="font-display text-[18px] font-bold text-ink">Roles &amp; permissions</h2>
          <div className="mt-4 space-y-2">
            {ROLE_ROWS.map((r) => (
              <div
                key={r.role}
                className="rounded-[12px] border border-line bg-surface p-3"
              >
                <div className="flex items-center gap-2">
                  <span className="text-[14px] font-semibold text-ink">{r.role}</span>
                  {r.role === CURRENT_ROLE ? (
                    <span className="rounded-full bg-chip-green-bg px-2 py-0.5 text-[11px] font-semibold text-chip-green-fg">
                      you
                    </span>
                  ) : null}
                </div>
                <p className="mt-1 text-[13px] text-muted">{capabilitySentence(r.can)}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-[18px] border border-line bg-white p-6">
          <h2 className="font-display text-[18px] font-bold text-ink">Case state flow</h2>
          <p className="mt-1 text-[12px] text-muted">
            A case can only move along these paths. Anything else is blocked.
          </p>
          <div className="mt-4 space-y-2">
            {STATE_FLOW.map((s) => (
              <div
                key={`${s.from}>${s.to}`}
                className="flex flex-wrap items-center gap-x-2 gap-y-1 rounded-[12px] border border-line bg-surface px-3 py-2.5 text-[13px]"
              >
                <span className="font-medium text-ink">{s.from}</span>
                <span className="text-muted">→</span>
                <span className="font-medium text-ink">{s.to}</span>
                <span className="text-[12px] text-muted">· {s.label}</span>
                <span className="ml-auto text-[12px] text-muted">
                  {s.roles.join(" / ")}
                </span>
              </div>
            ))}
          </div>
        </section>
      </div>

      <p className="mt-6 text-[12px] text-muted">
        Every state change and sign-off writes a receipt. Nothing here is a silent action.
      </p>
    </main>
  );
}
