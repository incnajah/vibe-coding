<?php

use App\Models\User;
use Filament\Facades\Filament;

/**
 * A generated Resource gets a navigation icon for free. A hand-written Page
 * does not, and the missing icon is only visible if someone opens the panel.
 * This catches it on every new page instead.
 */
it('gives every sidebar item an icon', function () {
    $admin = User::factory()->create(['is_admin' => true]);
    $this->actingAs($admin);
    Filament::setCurrentPanel('admin');

    $missing = [];

    foreach (Filament::getPanel('admin')->getPages() as $page) {
        if ($page::getNavigationIcon() === null && $page::shouldRegisterNavigation()) {
            $missing[] = $page;
        }
    }

    foreach (Filament::getPanel('admin')->getResources() as $resource) {
        if ($resource::getNavigationIcon() === null && $resource::shouldRegisterNavigation()) {
            $missing[] = $resource;
        }
    }

    expect($missing)->toBe([], 'these have no navigation icon: '.implode(', ', $missing));
});
