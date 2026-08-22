type Props = { title: string; description: string; action?: React.ReactNode }

/** Empty is design work, not a fallback: say what this screen is for, why it is
 *  empty, and what fills it. */
export function EmptyState({ title, description, action }: Props) {
    return (
        <div className="rounded-lg border border-dashed border-border bg-surface-muted px-6 py-12 text-center">
            <h2 className="text-lg font-semibold text-content">{title}</h2>
            <p className="mx-auto mt-2 max-w-md text-sm text-content-muted">{description}</p>
            {action && <div className="mt-6">{action}</div>}
        </div>
    )
}
