type Props = { children: React.ReactNode; className?: string }

export function Card({ children, className = '' }: Props) {
    return (
        <div
            className={`rounded-lg border border-border bg-surface-raised transition-colors
                        hover:border-border-strong ${className}`}
        >
            {children}
        </div>
    )
}
