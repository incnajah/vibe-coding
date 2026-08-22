type Props = { title: string; description?: string; eyebrow?: string }

export function PageHeader({ title, description, eyebrow }: Props) {
    return (
        <header className="space-y-3">
            {eyebrow && (
                <p className="text-xs font-semibold uppercase tracking-widest text-primary">{eyebrow}</p>
            )}
            <h1 className="text-2xl font-semibold tracking-tight text-content">{title}</h1>
            {description && <p className="max-w-2xl text-content-muted">{description}</p>}
        </header>
    )
}
