# Contraption Framework

[![Discord Invite](https://img.shields.io/discord/654142834030542878?label=Chat&style=flat-square)](https://discord.gg/jgdzysxjST)
[![Workshop](https://img.shields.io/steam/subscriptions/3154971187?logo=steam&label=Subscriptions&style=flat-square)](https://steamcommunity.com/sharedfiles/filedetails/?id=3154971187)
[![Linting Status](https://img.shields.io/github/actions/workflow/status/ACF-Team/CFW/glualint.yml?branch=main&label=Linter%20Status&style=flat-square)](https://github.com/ACF-Team/CFW/actions?query=workflow%3AGLuaLint)
[![Repository Size](https://img.shields.io/github/repo-size/ACF-Team/CFW?label=Repository%20Size&style=flat-square)](https://github.com/ACF-Team/CFW)
[![Commit Activity](https://img.shields.io/github/commit-activity/m/ACF-Team/CFW?label=Commit%20Activity&style=flat-square)](https://github.com/ACF-Team/CFW/graphs/commit-activity)

Monitors constraints to create "contraption" objects and adds callbacks for changes made to contraptions for efficient contraption-aware functionality.

For example, in order to calculate the total mass of a contraption traditionally one would need to iterate over every entity on the contraption and store this information somewhere.

With Contraption Framework (CFW), a callback is run whenever an entity is added to or removed from a contraption and the total mass is added to or subtracted from the total stored in memory on the contraption object.
