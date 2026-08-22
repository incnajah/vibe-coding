<?php

namespace App\Actions\Settings;

use App\Models\Setting;
use App\Support\Settings;
use Illuminate\Support\Facades\DB;

final class SaveSettings
{
    public function __construct(private Settings $settings) {}

    /** @param array<string, mixed> $values */
    public function handle(array $values, string $group = 'general'): void
    {
        DB::transaction(function () use ($values, $group) {
            foreach ($values as $key => $value) {
                Setting::updateOrCreate(
                    ['key' => $key],
                    ['value' => $value, 'group' => $group],
                );
            }
        });

        // Cache invalidation belongs with the write, not with the caller.
        $this->settings->forget();
    }
}
