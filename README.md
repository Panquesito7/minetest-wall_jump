# Minetest Wall Jump

> **Note**
>
> The mod is still WIP and is still missing a lot of stuff, cleanup, and other things.\
> However, it should be stable and playable without any major issues. Thanks for testing!

Allows the player to perform multiple wall jumps on Minetest!\
The mod has a variety of settings and customizations, from the number of wall jumps to configuring all the values for specific nodes or groups, which allows you to create a unique experience for your server. You can also configure specific armors to have different physics and values.

<!-- Add GIF here -->
<!-- Add YouTube link video here -->

## Settings

TODO: Add a list of settings found in settingtypes.txt here

<!-- Add a list of settings found in settingtypes.txt here -->

To configure the Realistic Mode (RLM), check out the `realistic_mode.lua` file.

### Configuring the RLM mode

TODO: Add a guide on how to configure the RLM mode

<!-- Add a guide on how to configure the RLM mode -->

## Known bugs

- When falling from very high and then sliding on the wall, sliding might not work well at all times (not sure if this is considered a bug or not).
- If you jump on a sticky wall and stay there, the player might not fully stick at times.
- Other bugs that happen at random times or very specific positions might have you jump very high, non-proper sliding, getting stuck, and other bugs.
- With a certain wall jump setup with a roof in the middle, particles might appear on the wrong node even if they shouldn't (the player is still touching the wall, though).

## Installation

- Unzip the archive, rename the folder to `wall_jump` and
place it in `..minetest/mods/`

- GNU/Linux: If you use a system-wide installation place
    it in `~/.minetest/mods/`.

- If you only want this to be used in a single world, place
    the folder in `..worldmods/` in your world directory.

For further information or help, see:\
<https://wiki.minetest.net/Installing_Mods>

## To-do

- Add all settings to `settingtypes.txt` (in progress).
- Add SkinsDB and 3D Armor support for the models.
- Add an in-game RLM configuration menu (?).
- Adjust the readme.
- Update the sounds to have higher quality.
- Create the jump and stick to wall models (#2, in progress).
- Clean up and tweak the code.
