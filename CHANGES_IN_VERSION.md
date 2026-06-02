<!--
This file is the contract between developers and the release-notes pipeline
(read by scripts/workflows/generate_release_notes.sh --changes-file).

Two sections:

  1. Above the "### Default Release Notes" header (this top part) is where you
     add version-specific bullets as the week's work lands. Each PR appends a
     line. The release-notes generator turns those bullets into App Store
     release notes copy.

  2. Below "### Default Release Notes" is the fallback pool. If the top section
     is empty when a release fires, the generator picks a random line from
     here so the App Store entry never ships with empty notes.

Rules:
  - Only lines that start with "- " (dash + space) count as notes. Anything
    else — including this comment and its "-->" delimiter — is ignored.
  - Write freely: apostrophes and "quotes" are safe. The text is read straight
    from this file and never passed through the workflow shell.

The clear-release-notes workflow wipes the top section after a release ships
and leaves the Default Release Notes section untouched.
-->

### Default Release Notes

- Improvements and bug fixes. Our bugs are now in therapy.
- Enhanced performance and stability. Crashes are so last season.
- Minor tweaks and optimizations. The kind only engineers will notice.
- General housekeeping and polishing. We swept the codebase under the rug.
- Bug squashing session complete. No bugs were harmed, okay maybe a few.
- Under the hood improvements. Where the real magic happens.
- Various fixes and enhancements. Sounds vague, but trust us, it is good.
- Maintenance update with love. And way too much coffee.
- Fine tuning for better experience. Like adjusting your playlist, but for apps.
- Quality of life improvements. Because you deserve it.
- Stability enhancements and fixes. Your app will not wobble anymore.
- Performance optimizations. We added a turbo button you cannot see.
- We fixed things that needed fixing. Very technical, we know.
- Some bugs have been shown the door. Do not let it hit you on the way out.
- Updated for smoother sailing. No more digital seasickness.
- Behind the scenes magic updates. Code wizards were involved.
- Small fixes, big impact. Kind of like duct tape.
- Routine maintenance complete. The app brushed its teeth.
