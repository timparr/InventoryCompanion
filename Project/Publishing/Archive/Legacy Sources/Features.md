# Inventory Companion Features

This overview describes features implemented in the current addon. For setup and step-by-step instructions, see [UserManual.bbcode](../../Source%20Documents/UserManual.bbcode).

## AutoCategory integration

The optional AutoCategory integration lets you manage native categories and Inventory Companion groups in one editor. Set independent Display and Priority orders for each supported inventory area, hide or show categories per area, and move the special Other heading without changing its catch-all matching behavior. AutoCategory remains responsible for classification and display; the integration is off by default.

## Bank and chest helpers

**Crafted-item deposit and withdrawal.** If, like me, you craft several days' worth of gear ahead with LazyWritCrafter, you know how repetitive it can be to move it between your backpack and bank by hand. You just want to jump into a trial, but the bank is full of other characters' crafted items. Deposit your tank's gear on top of those, and sorting it all out later can be a pain. Inventory Companion moves supported items between your backpack and bank with a single keypress. It only transfers items crafted by the current character, so your other characters' gear stays safe. The bank must be open, and you need to assign keys to the Deposit and Withdraw actions in the game's keybindings. Transfers are limited to the addon's built-in item list, which currently focuses on max-level crafting writ gear. (I should probably add all the other levels - I'll get to it sometime this year, or you could do it - its all in one file. If you want to - let me know - the repo's on github)

**House-chest stack merging.** If you have a lot of surveys or treasure maps in your bank and house chests, you may find yourself hunting for the chest with the Blacksmith's Survey for Auridon so you can add the copies from your backpack. Now you just need to open each chest in turn. Inventory Companion looks for matching stacks with room and moves matching items from your backpack onto them. You can turn this feature off in the settings.

**Move just one item without the 'split' window. Move all but one item.** Use the right-click options to deposit or withdraw one item, or all but one, from a stack in your bank, backpack, house chest or guild bank. Guild-bank partial deposits require deposit access, a free backpack slot and a free guild-bank slot. Partial withdrawals temporarily take the whole stack and return the remainder; they require both deposit and withdrawal access, at least two free backpack slots and a free guild-bank slot. The account-wide **Enable Partial Guild Bank Withdrawals** setting controls withdrawals and is on by default.

## Space and currency panels

**Backpack and bank capacity bars.** It's easy to lose track of how close your storage is to full. Inventory Companion provides movable progress bars showing used slots against capacity. In the settings, choose which resources get their own bar and set the colors and thresholds for warning (amber) and danger (red). Currently ZOS only has three capped resources - backpack space, bank space, and Transmute Crystals, each of which can have its own bar. It would be good to have the bar only pop up at a certain percentage value as well - but I haven't done that yet.

**Currency Summary Panel.** There are a *lot* of currencies in this game: Tel Var, Transmute Crystals, Crown Gems, Outfit Change Tokens, Trade Bars, and more. It can be annoying to open your inventory, click the currency tab, and squint at the screen to see how much of each you have. Inventory Companion helps by listing available currencies in the settings, where you can choose which ones to track and whether to show your character's balance, your bank balance, or both. You can also enable a notification for changes to a currency. The panel can hide currencies with a zero balance, too. For example, track Tel Var on your character and it stays out of sight until you collect some; deposit it in the bank and it disappears again if the bank location isn't selected.

## Item tracking

**Live Item Tracker.** It doesn't stop with currencies. We all care more about some items than others (sorry, Lorkhan's Tears). Want to see at a glance how many Nirncrux you have, or get a notification when you find one? Inventory Companion provides a movable HUD panel for the items that matter to you. Choose whether to show each item on the panel, notify when you gain it, or both. Add items in the tracking editor, or right-click an item in your backpack or bank and choose **Add to Tracked Items**.

**Custom Groups.** Too much work to track items one by one? You can create groups with lists of name patterns and wildcards. Each pattern can be an Include or Exclude: a group includes an item when at least one Include matches and no Exclude matches. For example, a "Treasure Maps" group can include "*treasure map*" and exclude "*cyrodiil*". Exclusions narrow only their own group; an item may still match other groups or be tracked individually. Matching items can appear together in a group on the tracker, and you can enable notifications when you gain a match. Expand the group to see its items, or collapse it to see the group total. Groups with more than 200 eligible items show an overflow message instead of item rows; narrow their patterns to display the items. Summary counts still include all matching items.

**Built-in item groups.** But even that seems like too much trouble? You don't have to set up groups from scratch: the addon comes with a collection of groups I personally use, plus some I thought other players might like. I may be a bit obsessive about some things and laissez-faire about others, so you can rename a built-in group, hide it, change its patterns, or just laugh at it.

## Profiles

**Account-wide and character-specific profiles.** By default, characters share the account-wide profile. Use Character Settings to retain a separate full profile for a character, including tracked items and groups, panel preferences and positions, editor filters, and AutoCategory layouts. First use copies the account profile; later switches resume the retained character settings. In Main Settings, choose a source in Copy From and select Copy Full Profile to replace the active profile after confirmation. Integration enablement, transfer delay, chest-stack merging, and diagnostic controls remain account-wide.
