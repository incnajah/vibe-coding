/** One place that owns reading measure and paragraph rhythm. */
export function Prose({ children }: { children: React.ReactNode }) {
    return <div className="space-y-6 text-base text-content">{children}</div>
}
