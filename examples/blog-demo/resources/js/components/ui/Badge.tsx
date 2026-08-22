type Props = { children: React.ReactNode; tone?: 'neutral' | 'accent' }

export function Badge({ children, tone = 'neutral' }: Props) {
    const tones = {
        neutral: 'bg-surface-muted text-content-muted',
        accent: 'bg-accent-bg text-primary',
    }
    return (
        <span
            className={`inline-flex items-center rounded-sm px-2 py-1 text-xs font-medium tracking-wide ${tones[tone]}`}
        >
            {children}
        </span>
    )
}
