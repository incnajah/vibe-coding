<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<\App\Models\Post> */
class PostFactory extends Factory
{
    public function definition(): array
    {
        $title = rtrim($this->faker->sentence(6), '.');

        return [
            'user_id' => User::factory(),
            'title' => $title,
            'slug' => Str::slug($title).'-'.Str::lower(Str::random(5)),
            'excerpt' => $this->faker->sentence(14),
            'body' => collect($this->faker->paragraphs(6))->implode("\n\n"),
            'published_at' => now()->subDays($this->faker->numberBetween(1, 60)),
        ];
    }

    public function draft(): static
    {
        return $this->state(fn () => ['published_at' => null]);
    }
}
