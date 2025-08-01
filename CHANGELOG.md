# Changelog

All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

## [1.19.0](https://github.com/mumu-lhl/Ciyue/compare/v1.18.0..v1.19.0) - 2025-08-01

### Features

- Audio settings are now officially available
- Support in-dictionary audio playback
- Support importing multiple .mdd files (e.g., xxx.1.mdd, xxx.2.mdd, xxx.3.mdd)
- Add Google Translate and DeepLX as translation providers
- Add history for translation and writing check
- Add logs page
- Support multi-select on search history for bulk delete, add to wordbook, and remove from wordbook

### Bugs

- Fix misaligned inputs for API Key and AI Model on the AI Settings page

### UI

- Redesign AI Settings page
- Redesign Translate page

## [1.18.0](https://github.com/mumu-lhl/Ciyue/compare/v1.17.0..v1.18.0) - 2025-07-20

### Features

* Auto pop up keyboard in main search tab
* Add storage management
* Add multiselectmode on wordbook page
* Add writing check

### Bugs

* Fix add word to wordbook on home page

## [1.17.0] - 2025-07-06

### Features

* Show changelog after updating
* Cache AI Explanation

### UI

* Refactor settings page

### Bugs

* Fix adding dictionaries repeatly by refresh button
* Fix show not support dictionary wrongly


---
## [1.16.0-beta.4](https://github.com/mumu-lhl/Ciyue/compare/v1.16.0-beta.3..v1.16.0-beta.4) - 2025-05-31

### Miscellaneous Chores

- **(release)** update APK naming conventions for Android builds - ([46e31c1](https://github.com/mumu-lhl/Ciyue/commit/46e31c1f79a88b45eb23e34613d76fda41351d34)) - Mumulhl

---
## [1.16.0-beta.3](https://github.com/mumu-lhl/Ciyue/compare/v1.16.0-beta.2..v1.16.0-beta.3) - 2025-05-31

### Miscellaneous Chores

- **(appimage)** fix build - ([0ed41d3](https://github.com/mumu-lhl/Ciyue/commit/0ed41d3fa8406ea8f33dff91a4f3febaffd117e2)) - Mumulhl

---
## [1.16.0-beta.2](https://github.com/mumu-lhl/Ciyue/compare/v1.16.0-beta.1..v1.16.0-beta.2) - 2025-05-31

### Miscellaneous Chores

- **(appimage)** fix build - ([491562d](https://github.com/mumu-lhl/Ciyue/commit/491562d0b0214fbe2d87acbd9ae14c4bd87ee468)) - Mumulhl

---
## [1.16.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.15.0..v1.16.0-beta.1) - 2025-05-31

### Bug Fixes

- fix anthropic url - ([9239a54](https://github.com/mumu-lhl/Ciyue/commit/9239a546103a03d92dc8a96bd5c23524cd777cb4)) - Mumulhl
- not show not support notice on android - ([e093ad4](https://github.com/mumu-lhl/Ciyue/commit/e093ad49ced1507ec4e7dc0ba3331b3e1b2ecde9)) - Mumulhl

### Features

- **(audio)** support any audio format - ([aa088a9](https://github.com/mumu-lhl/Ciyue/commit/aa088a911a77e1799d700719609b616ef9223f09)) - Mumulhl
- **(translation)** translated using Weblate (Sardinian) - ([5a6e225](https://github.com/mumu-lhl/Ciyue/commit/5a6e225dc7cbf2cbc6065440251e577561fba770)) - Ajeje Brazorf
- add more languages on translate page - ([2bb2348](https://github.com/mumu-lhl/Ciyue/commit/2bb2348bb9f77bd55959c728ff0363ce4d4581fa)) - Mumulhl

### Miscellaneous Chores

- **(appimage)** add update information - ([0c83ae1](https://github.com/mumu-lhl/Ciyue/commit/0c83ae13741bf191bca8d421a5538662a5fa6518)) - Mumulhl
- **(build)** support AppImage - ([7689b8d](https://github.com/mumu-lhl/Ciyue/commit/7689b8dcf57825ee700bd88e30215e38615d418a)) - Mumulhl
- **(ci)** update APK naming conventions in workflows - ([5856c7b](https://github.com/mumu-lhl/Ciyue/commit/5856c7befcdfba02b246ad3a9ca0d9df084e7301)) - Mumulhl
- **(ci)** add AppImage build release workflow - ([a776c5c](https://github.com/mumu-lhl/Ciyue/commit/a776c5c975e63e4b12b0724eefd680c242d65e71)) - Mumulhl
- **(gradle)** upgrade AGP - ([7b7e334](https://github.com/mumu-lhl/Ciyue/commit/7b7e334e5c157e8dc8ce38d9f45158bf3ed94237)) - Mumulhl
- **(gradle)** upgrade kotlin to 2.1.0 - ([742c901](https://github.com/mumu-lhl/Ciyue/commit/742c901c0abb37bcafee578b746a9d0ef7c959ad)) - Mumulhl
- **(gradle)** enable flavour - ([dafe61f](https://github.com/mumu-lhl/Ciyue/commit/dafe61fb5ea4b4711b98d6af9841ad2b308b6e97)) - Mumulhl
- **(gradle)** update version code for different archs - ([bda15bc](https://github.com/mumu-lhl/Ciyue/commit/bda15bc540a01c4902e5b8fa092ac628bfb5d723)) - Mumulhl
- update Flutter version to 3.32.1 in release workflow - ([0129818](https://github.com/mumu-lhl/Ciyue/commit/012981898918a6da51eacb292b67563b82f238e9)) - Mumulhl
- standardize app name string key to 'app_name' across all locales - ([cf97953](https://github.com/mumu-lhl/Ciyue/commit/cf97953165919715a958b2ce1d215f2e0f0bc344)) - Mumulhl

### Refactoring

- **(translation)** migrate i18n placeholders to named arguments - ([066a0c1](https://github.com/mumu-lhl/Ciyue/commit/066a0c189f91ac31663bec07bc3026262bddc22e)) - Mumulhl
- **(ui)** settings page - ([571fa38](https://github.com/mumu-lhl/Ciyue/commit/571fa3877eae1605053b8c39dbdb33dca9da82b5)) - Mumulhl

---
## [1.15.0](https://github.com/mumu-lhl/Ciyue/compare/v1.14.1..v1.15.0) - 2025-05-25

### Bug Fixes

- **(audio)** add audio bug on Android - ([148da34](https://github.com/mumu-lhl/Ciyue/commit/148da34251f981d51df2707b5fc0be5b6e4be74c)) - Mumulhl

### Features

- **(audio)** implement audio settings model - ([512c00a](https://github.com/mumu-lhl/Ciyue/commit/512c00ab5902802a7ca8d1f9e8d678236a3b01f1)) - Mumulhl
- **(audio)** add title field to MddAudioList and update related functionality - ([0b986ef](https://github.com/mumu-lhl/Ciyue/commit/0b986efcc5ff1be365cf3268682db20284d4fb8c)) - Mumulhl
- **(audio)** add order field to MddAudioList and implement reordering functionality - ([d03ea93](https://github.com/mumu-lhl/Ciyue/commit/d03ea9359052859af7196d2c217deecf7c5d26e1)) - Mumulhl
- **(audio)** add TTS to audio list - ([0c2fb0b](https://github.com/mumu-lhl/Ciyue/commit/0c2fb0ba5ef7599352f82772d69be378174f64ac)) - Mumulhl
- **(audio)** support add mdd audio on Android - ([cbc5495](https://github.com/mumu-lhl/Ciyue/commit/cbc54953fd1ab40a3da9063c3a6149be8fefff2e)) - Mumulhl
- **(audio)** support play sound in word display page - ([1529b17](https://github.com/mumu-lhl/Ciyue/commit/1529b1768e19c8a2c3777a19e337b23f2602d9e5)) - Mumulhl
- **(database)** add mdd audio table and migration - ([4ad4df9](https://github.com/mumu-lhl/Ciyue/commit/4ad4df943f4d349825e5c1d25276a369cbffeab6)) - Mumulhl
- **(model)** update Gemini 2.5 Flash Preview version - ([ad89c55](https://github.com/mumu-lhl/Ciyue/commit/ad89c5530ba6ce9d610e25bccee6e6815c49c4f2)) - Mumulhl
- **(model)** add Claude 4 - ([956f678](https://github.com/mumu-lhl/Ciyue/commit/956f6784cd6118187d95ea06f6a64315dd7af46a)) - Mumulhl
- add 'Alpha' tag to experimental settings features - ([f2bb70b](https://github.com/mumu-lhl/Ciyue/commit/f2bb70bdc2f834e683b75ab11b26b5d2fa0d65f9)) - Mumulhl
- fake webview for linux - ([434dbc0](https://github.com/mumu-lhl/Ciyue/commit/434dbc0499905d6886832b241877e430f04ff959)) - Mumulhl

### Miscellaneous Chores

- **(build)** fix linux build - ([6298550](https://github.com/mumu-lhl/Ciyue/commit/6298550cd805aafb11ac5a02ae8a7c04ef6a9f4e)) - Mumulhl
- **(deps)** bump gpt_markdown from 1.0.18 to 1.0.19 - ([e3a3bee](https://github.com/mumu-lhl/Ciyue/commit/e3a3beef0802ca6c58a096e7097ac3aa76d24727)) - dependabot[bot]
- **(deps)** bump flutter_local_notifications from 19.2.0 to 19.2.1 - ([2e801ed](https://github.com/mumu-lhl/Ciyue/commit/2e801edb2e6e1c580c0ebdd4b236f5f7febf6925)) - dependabot[bot]
- **(deps)** update intl to 0.20.2 - ([a31bb0e](https://github.com/mumu-lhl/Ciyue/commit/a31bb0e1830b18589d274d54af37aef810948ae9)) - Mumulhl
- **(deps)** update - ([8da8bcc](https://github.com/mumu-lhl/Ciyue/commit/8da8bccbc8f5d273c503dfb7cdcda102b37b7b01)) - Mumulhl
- **(release)** update flutter version - ([dee68fa](https://github.com/mumu-lhl/Ciyue/commit/dee68fa8a59f463276a647af3fd03c07b3298527)) - Mumulhl

### Refactoring

- **(ai)** refactor AI Explain Word - ([f6632b1](https://github.com/mumu-lhl/Ciyue/commit/f6632b153a37a9d3d5b51703afb499b7d2483f8a)) - Mumulhl
- **(audio)** refactor audio management and add AudioModel for better state handling - ([a721666](https://github.com/mumu-lhl/Ciyue/commit/a7216668c777485da70894a54d1f349c31ef20ec)) - Mumulhl
- refactor database - ([c7d24ed](https://github.com/mumu-lhl/Ciyue/commit/c7d24eddddaa7b6efd70684d2594359718d379f9)) - Mumulhl

### Style

- format code - ([9d97ea2](https://github.com/mumu-lhl/Ciyue/commit/9d97ea268a0627c9392585010b32a90bc61b9f03)) - Mumulhl
- format code - ([efb798f](https://github.com/mumu-lhl/Ciyue/commit/efb798f2fe9200bb38627d1d60cb2d3d0ca4f917)) - Mumulhl

---
## [1.14.1](https://github.com/mumu-lhl/Ciyue/compare/v1.14.0..v1.14.1) - 2025-05-18

### Bug Fixes

- add dictionary on Android - ([01e31d7](https://github.com/mumu-lhl/Ciyue/commit/01e31d791b8750a9cd618595c37c5811ad7d1971)) - Mumulhl

---
## [1.14.0](https://github.com/mumu-lhl/Ciyue/compare/v1.14.0-beta.2..v1.14.0) - 2025-05-18

### Bug Fixes

- fix loading dialog in Android - ([42d75b4](https://github.com/mumu-lhl/Ciyue/commit/42d75b43069e31d3e7ce2a2ef3402f855e518da0)) - Mumulhl
- fix returned type of initHandler - ([74da32c](https://github.com/mumu-lhl/Ciyue/commit/74da32c94e95d9e032101a5c1953160ceb86c1b1)) - Mumulhl

### Features

- new default explanation prompt - ([6952da0](https://github.com/mumu-lhl/Ciyue/commit/6952da0af059de8ab06cf0c0c24d8e916aaca261)) - Mumulhl
- Add slide transition to word page - ([439c6e2](https://github.com/mumu-lhl/Ciyue/commit/439c6e22f7b121914f9984f06d99cd5839f2c964)) - Mumulhl

### Refactoring

- **(animation)** refacotr page transition - ([e9675c0](https://github.com/mumu-lhl/Ciyue/commit/e9675c0c5414daf91bf0f35dbf76956b664a9cd9)) - Mumulhl

---
## [1.14.0-beta.2](https://github.com/mumu-lhl/Ciyue/compare/v1.14.0-beta.1..v1.14.0-beta.2) - 2025-05-17

### Features

- **(translation)** finish translation - ([cb65a7a](https://github.com/mumu-lhl/Ciyue/commit/cb65a7a9fbf53e0d8fcf2ff444fad40092286be5)) - Mumulhl

### Miscellaneous Chores

- **(build)** remove flavors - ([e2ee551](https://github.com/mumu-lhl/Ciyue/commit/e2ee55167eff2dd0ca07ea2e3451cd16bff3963b)) - Mumulhl

---
## [1.14.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.13.0..v1.14.0-beta.1) - 2025-05-17

### Bug Fixes

- **(floating_window)** disable drag - ([d1109c8](https://github.com/mumu-lhl/Ciyue/commit/d1109c82e3eb2fc60ee356729692a932a5680095)) - Mumulhl
- **(floating_window)** not focusable - ([353c793](https://github.com/mumu-lhl/Ciyue/commit/353c79393c345ab7729b90bec5594bc401b14c28)) - Mumulhl
- history - ([8f51d55](https://github.com/mumu-lhl/Ciyue/commit/8f51d55ce8c3885621811496488b00e985d205ee)) - Mumulhl
- add loading message for file copying process - ([234dace](https://github.com/mumu-lhl/Ciyue/commit/234dace9aca9317ed3546117df02fe6c72781176)) - Mumulhl
- set windows webview2 directory - ([ac62170](https://github.com/mumu-lhl/Ciyue/commit/ac621709a870879e22331008e4554502e6724baf)) - Mumulhl
- only show floating window when permission is enabled - ([8c166f1](https://github.com/mumu-lhl/Ciyue/commit/8c166f1cbd8ca08d5ec00184640f2502961bfb76)) - Mumulhl

### Features

- **(ai translate)** add Hindi language - ([ea32be3](https://github.com/mumu-lhl/Ciyue/commit/ea32be31869a67a7dfd0df436707d9aebc313e01)) - Mumulhl
- **(floating window)** implement close window when clicks outside the window - ([cc9d52a](https://github.com/mumu-lhl/Ciyue/commit/cc9d52ad6e7f9fc8d6c40f19b05b6980447a1c9d)) - Mumulhl
- **(floating window)** click back button to close window - ([f77e149](https://github.com/mumu-lhl/Ciyue/commit/f77e149ea405b70e40b1c729c7a2e9ba53685d7e)) - Mumulhl
- **(translation)** translated using Weblate (Sardinian) - ([df889ef](https://github.com/mumu-lhl/Ciyue/commit/df889efec68527fb7dc65eaddcf53821a684843b)) - Ajeje Brazorf
- **(translation)** translated using Weblate (Persian) - ([7ed176a](https://github.com/mumu-lhl/Ciyue/commit/7ed176a819065d0f5595db93ad40b1296022d73c)) - Mo
- implement floating window service initially - ([26d6453](https://github.com/mumu-lhl/Ciyue/commit/26d64534b2685e77ad0777c541c81fac744f1078)) - Mumulhl
- support add mutiple dictionaries at once - ([27c2fd1](https://github.com/mumu-lhl/Ciyue/commit/27c2fd1bc29e3ceca5342457068d35c7d29c4aeb)) - Mumulhl

### Miscellaneous Chores

- **(build)** add dev flavor for android - ([65e3ae5](https://github.com/mumu-lhl/Ciyue/commit/65e3ae5f8b8f55917a3b1bab4feac41b3a5b9a64)) - Mumulhl
- **(build)** add production flavor for android - ([c19ad56](https://github.com/mumu-lhl/Ciyue/commit/c19ad5609212e45dec7314f50469f0d1395024eb)) - Mumulhl
- **(deps)** bump flutter_local_notifications from 19.1.0 to 19.2.0 - ([a17f969](https://github.com/mumu-lhl/Ciyue/commit/a17f9692e1667b04afb025c5e6a6a915b1ef423c)) - dependabot[bot]
- **(deps)** bump go_router from 15.1.1 to 15.1.2 - ([6d7dd92](https://github.com/mumu-lhl/Ciyue/commit/6d7dd92db6eb93045ec47feb88cdab6d2263ac96)) - dependabot[bot]
- **(deps-dev)** bump esbuild from 0.25.3 to 0.25.4 in /docs - ([c674ffd](https://github.com/mumu-lhl/Ciyue/commit/c674ffd06b61f3e4bc3b00c03512ffbf68bfeafb)) - dependabot[bot]
- **(release)** add translation label to changelog - ([c9caf8b](https://github.com/mumu-lhl/Ciyue/commit/c9caf8bb9716e833b7867e333cb49d7db8c95472)) - Mumulhl
- **(vscode)** add launch configuration for Flutter Android development - ([274d5b4](https://github.com/mumu-lhl/Ciyue/commit/274d5b4be83e3df6a580569e0ce1ab789f40ece1)) - Mumulhl

### Refactoring

- **(manage dictionaries)** enhance dictionary management features and improve state handling - ([a6e9d50](https://github.com/mumu-lhl/Ciyue/commit/a6e9d50fca35d3be2422511c7c657feff0beeb3a)) - Mumulhl

---
## [1.13.0](https://github.com/mumu-lhl/Ciyue/compare/v1.12.1..v1.13.0) - 2025-05-11

### Bug Fixes

- **(ui)** fix focus - ([177644b](https://github.com/mumu-lhl/Ciyue/commit/177644befcbd443a1014b10a7fb62e2568e50751)) - Mumulhl
- search result - ([3d00a91](https://github.com/mumu-lhl/Ciyue/commit/3d00a918d59239fbe58c1808d7422636813ac950)) - Mumulhl

### Features

- **(ai)** add Ollama provider - ([a21651e](https://github.com/mumu-lhl/Ciyue/commit/a21651eedf70744c481d3333c1feda47c65d1f9a)) - Mumulhl
- **(model)** update Gemini 2.5 Pro to the latest - ([f44f5c1](https://github.com/mumu-lhl/Ciyue/commit/f44f5c1a1f992bc131abd68036b24a18128f0b2d)) - Mumulhl
- **(settings)** add support for custom AI API Url provider - ([1391415](https://github.com/mumu-lhl/Ciyue/commit/13914158be080dca06dac2600ead07b2944ef509)) - Mumulhl
- **(translation)** translate all languages - ([7687d31](https://github.com/mumu-lhl/Ciyue/commit/7687d315ceebab1ad18897e313f91fd790f445bf)) - Mumulhl
- add audio settings - ([b3f6e38](https://github.com/mumu-lhl/Ciyue/commit/b3f6e3864ff9e4f52b5c0f615d4550bc512914fd)) - Mumulhl
- add Catalan language option to language selector - ([0ba8a8a](https://github.com/mumu-lhl/Ciyue/commit/0ba8a8a211d8f8d4cf7ef1fc1fdefe5f1f773003)) - Mumulhl

### Miscellaneous Chores

- **(build)** update Java compatibility to version 21 - ([c17af99](https://github.com/mumu-lhl/Ciyue/commit/c17af9942af44ebe4ba88d53bd34c9e596ede9a9)) - Mumulhl
- **(build)** adjust version code - ([08ecba3](https://github.com/mumu-lhl/Ciyue/commit/08ecba3124f2d2921f09c3a58dcce05299259b99)) - Mumulhl
- **(deps)** bump provider from 6.1.4 to 6.1.5 - ([7b1c46a](https://github.com/mumu-lhl/Ciyue/commit/7b1c46abda8474bb05d215de5196177b72ef9a9b)) - dependabot[bot]
- **(deps)** bump drift from 2.26.0 to 2.26.1 - ([8b78012](https://github.com/mumu-lhl/Ciyue/commit/8b780127fc1df213386555ffbff9d1816dedb01a)) - dependabot[bot]
- **(deps)** bump drift_dev from 2.26.0 to 2.26.1 - ([e7dd221](https://github.com/mumu-lhl/Ciyue/commit/e7dd2219ab6d1df7df62de1a79b251db45c57fac)) - dependabot[bot]
- **(plugins)** upgrade Android Gradle plugin to version 8.10.0 - ([c98c4fd](https://github.com/mumu-lhl/Ciyue/commit/c98c4fda0835b7de90831adc6c508a1ced541854)) - Mumulhl
- adjust version code - ([420efcc](https://github.com/mumu-lhl/Ciyue/commit/420efcc4134cee8bdc7d1ed010918e75cdbc5c9a)) - Mumulhl
- linux runner - ([2ccb038](https://github.com/mumu-lhl/Ciyue/commit/2ccb0380a25c45cc18f5575dc3047d1528d058ef)) - Mumulhl

### Refactoring

- **(search)** replace autofocus with focusNode in search bar implementation - ([0fde1d9](https://github.com/mumu-lhl/Ciyue/commit/0fde1d906050b3f80015939c1ead874c2bd7afba)) - Mumulhl

### Style

- format code - ([7469d78](https://github.com/mumu-lhl/Ciyue/commit/7469d78bcde03bb242e12e6177412ea4b4d0e20d)) - Mumulhl

---
## [1.12.1](https://github.com/mumu-lhl/Ciyue/compare/v1.12.0..v1.12.1) - 2025-05-05

### Miscellaneous Chores

- **(build)** fix version code - ([674e5fc](https://github.com/mumu-lhl/Ciyue/commit/674e5fccbde659eefffbc74571207fa4bac7616f)) - Mumulhl

---
## [1.12.0](https://github.com/mumu-lhl/Ciyue/compare/v1.11.0..v1.12.0) - 2025-05-05

### Bug Fixes

- enable auto-update based on user settings - ([4af008c](https://github.com/mumu-lhl/Ciyue/commit/4af008c642fccd40b0e37f555fb8c25aac34aca6)) - Mumulhl

### Features

- **(icon)** add Windows icon - ([c52dd3c](https://github.com/mumu-lhl/Ciyue/commit/c52dd3c08c86f96fc7c3562859ee471e6d3c7844)) - Mumulhl
- **(translation)** translated using Weblate (Russian) - ([c46c476](https://github.com/mumu-lhl/Ciyue/commit/c46c4766be79d1bd7a16578023b0c2b270346206)) - Xapitonov
- **(translation)** translated using Weblate (Tamil) - ([7e46baa](https://github.com/mumu-lhl/Ciyue/commit/7e46baac37f7d8be695fe28eb9185388a549f9d4)) - தமிழ்நேரம்
- **(translation)** translated using Weblate (Spanish) - ([cc9b38b](https://github.com/mumu-lhl/Ciyue/commit/cc9b38b9afa923fe0e4c2f396a78406636af18fa)) - Adolfo Jayme Barrientos
- **(translation)** added translation using Weblate (Catalan) - ([ed00458](https://github.com/mumu-lhl/Ciyue/commit/ed00458706503d803a4e9c7cb81cdc82a28dd4f8)) - Adolfo Jayme Barrientos
- **(translation)** translated using Weblate (Catalan) - ([f5c49d7](https://github.com/mumu-lhl/Ciyue/commit/f5c49d7ef20d46033e390c12c17fbff52b672325)) - Adolfo Jayme Barrientos
- implement auto update - ([43b1968](https://github.com/mumu-lhl/Ciyue/commit/43b19682d45ca1cb85d1c3d5b3f72716a3b81224)) - Mumulhl

### Miscellaneous Chores

- **(build)** migrate to kts - ([264a1a6](https://github.com/mumu-lhl/Ciyue/commit/264a1a6abfcd333395e74b9012318c2200958a7f)) - Mumulhl
- **(ci)** ensure paths are correctly specified for VitePress deploy - ([ec9816a](https://github.com/mumu-lhl/Ciyue/commit/ec9816af70c1746fc6d34713f1dc119181472b48)) - Mumulhl
- **(ci)** update flutter - ([f9e46c9](https://github.com/mumu-lhl/Ciyue/commit/f9e46c93b18309ec4d0a884ca79448a9be83703e)) - Mumulhl
- **(ci)** fix release - ([581e342](https://github.com/mumu-lhl/Ciyue/commit/581e3420bcf4bd0f34e85f02e71c1e583d408c88)) - Mumulhl
- **(deps)** update - ([ad03c73](https://github.com/mumu-lhl/Ciyue/commit/ad03c7340cac1058a6b5789b2f9df94aeb473a0c)) - Mumulhl
- **(deps)** bump gpt_markdown from 1.0.17 to 1.0.18 - ([0bdff2a](https://github.com/mumu-lhl/Ciyue/commit/0bdff2a7ff18dc86d1a681589db7f19871c6e190)) - dependabot[bot]
- **(deps)** bump vite in /docs in the npm_and_yarn group - ([82221e7](https://github.com/mumu-lhl/Ciyue/commit/82221e78180337dab8c1767c3a1ede7cb40789ff)) - dependabot[bot]
- **(deps-dev)** bump esbuild from 0.25.2 to 0.25.3 in /docs - ([c34d741](https://github.com/mumu-lhl/Ciyue/commit/c34d7410414283cc7d260123a3b1193a2f8fa176)) - dependabot[bot]
- prefer double quotes - ([26dcc4c](https://github.com/mumu-lhl/Ciyue/commit/26dcc4c1843bc831db732c19e168c3776a88284d)) - Mumulhl

### Refactoring

- **(dictionary)** refactor dictionary management - ([aff2377](https://github.com/mumu-lhl/Ciyue/commit/aff23775ebba86a4aa93e78cfa5274e9f5859442)) - Mumulhl
- **(dictionary)** improve state management and simplify dictionary checks - ([a61b5c5](https://github.com/mumu-lhl/Ciyue/commit/a61b5c5a27c13b572c2783086afbea82579c0b85)) - Mumulhl
- **(history)** add HistoryModel - ([e329349](https://github.com/mumu-lhl/Ciyue/commit/e329349e6bd2afc983a5e0990ca780b1c944cfaa)) - Mumulhl
- **(home)** restructure HomeScreen and related components for improved readability and functionality - ([aa8e786](https://github.com/mumu-lhl/Ciyue/commit/aa8e786c42e31075d55390acb5a320a4d440f5c0)) - Mumulhl
- **(ui)** improve search ui - ([f8ddcc6](https://github.com/mumu-lhl/Ciyue/commit/f8ddcc68a5d18138a49c02b5d005dcd1fe587446)) - Mumulhl
- refactor update - ([9713d06](https://github.com/mumu-lhl/Ciyue/commit/9713d06c9f1ecb50c1269bdb82cdbabb34b12e84)) - Mumulhl
- move files to services directory - ([a51ffe1](https://github.com/mumu-lhl/Ciyue/commit/a51ffe1211ca6ec2c719fc2b4c2a96729c570661)) - Mumulhl
- refactor ai.dart - ([5e30372](https://github.com/mumu-lhl/Ciyue/commit/5e303724bf5b4e04df40bad2fbac84b6360e2f94)) - Mumulhl
- move files to directories - ([6d58cf2](https://github.com/mumu-lhl/Ciyue/commit/6d58cf2794debece778820636f8105974d2d4a87)) - Mumulhl
- improve export - ([7278ab9](https://github.com/mumu-lhl/Ciyue/commit/7278ab9c0d9f0f1459bf477d0f7a0c5f3c727b7e)) - Mumulhl
- refactor HomeScreen components - ([d37c878](https://github.com/mumu-lhl/Ciyue/commit/d37c878f3272a5fab9318db0e2a74d052542f03b)) - Mumulhl
- streamline search functionality and improve state management - ([c7953b8](https://github.com/mumu-lhl/Ciyue/commit/c7953b812b333efc8426e4daa591798e1735ff3d)) - Mumulhl

### Style

- format code - ([5aebf76](https://github.com/mumu-lhl/Ciyue/commit/5aebf761d47339cb46e7e0ac101aaa59ba55b67e)) - Mumulhl

---
## [1.11.0](https://github.com/mumu-lhl/Ciyue/compare/v1.10.0..v1.11.0) - 2025-04-19

### Bug Fixes

- **(config)** correct base path in VitePress configuration - ([d0cd1f0](https://github.com/mumu-lhl/Ciyue/commit/d0cd1f051b1abd8050e7faabe246ac26bc28abd3)) - Mumulhl

### Documentation

- **(web)** add web docs - ([771eed7](https://github.com/mumu-lhl/Ciyue/commit/771eed7d0e9181e5227f9d8a1fbda4b59669a3ab)) - Mumulhl

### Features

- **(model)** add SiliconFlow and SiliconFlow China - ([0ee9fc0](https://github.com/mumu-lhl/Ciyue/commit/0ee9fc0b95fe429c2951b9456dac6e90a5704d0f)) - Mumulhl
- **(model)** add Zhipu - ([01be78e](https://github.com/mumu-lhl/Ciyue/commit/01be78e2f42528ede1a0f9788e0c4aaf31d14ea3)) - Mumulhl
- **(model)** add xAI - ([dcf9c60](https://github.com/mumu-lhl/Ciyue/commit/dcf9c6022445769c3847536af0134f48461430b7)) - Mumulhl
- **(translation)** translated using Weblate (Chinese (Simplified Han script)) - ([6c0b955](https://github.com/mumu-lhl/Ciyue/commit/6c0b955d395a491608f0724422e8534a9d3ceffb)) - 何意挽秋風
- **(translation)** translated using Weblate (Chinese (Traditional Han script)) - ([fcbe4a9](https://github.com/mumu-lhl/Ciyue/commit/fcbe4a9bb952ff2b08cc6a6c4e78aabf6f275055)) - 何意挽秋風
- **(ui)** set navigation rail to extended state in wide landscape - ([e043bc8](https://github.com/mumu-lhl/Ciyue/commit/e043bc81f17da238830240367fee00362531054b)) - Integral
- add new AI models to the settings configuration - ([10dcb6f](https://github.com/mumu-lhl/Ciyue/commit/10dcb6f642da4be6e64c0bd80418017607964dda)) - Mumulhl
- delete associated .mdx and .mdd files on dictionary removal for Android - ([2c1e275](https://github.com/mumu-lhl/Ciyue/commit/2c1e275952d1acdb4922d10794c033c30a956d45)) - Mumulhl
- enhance loading dialog with dynamic text updates and refactor state management - ([a95fba1](https://github.com/mumu-lhl/Ciyue/commit/a95fba107dbd15f262ae14f1c042c5a16a0d87c5)) - Mumulhl
- add search bar functionality in word display - ([b499ff8](https://github.com/mumu-lhl/Ciyue/commit/b499ff8584bb3c7af9e38f5740810f7e043c7e42)) - Mumulhl

### Miscellaneous Chores

- **(ci)** update workflows and ignore files for VitePress deployment - ([76432e4](https://github.com/mumu-lhl/Ciyue/commit/76432e44e14fdaf9ea02210e3ecf1087b930f410)) - Mumulhl
- **(ci)** install pnpm - ([4288967](https://github.com/mumu-lhl/Ciyue/commit/4288967a6736a6c93cb34ef0a45c8d9c1b4837d8)) - Mumulhl
- **(ci)** add permissions for workflow - ([760c264](https://github.com/mumu-lhl/Ciyue/commit/760c2643c01b05dd52523c815975fa87608b9413)) - Mumulhl
- **(dependabot)** update configuration for npm package ecosystem - ([7757007](https://github.com/mumu-lhl/Ciyue/commit/7757007869ff52735059e2a7fbee9f5bb26e33d3)) - Mumulhl
- **(deps)** bump flutter_local_notifications from 19.0.0 to 19.1.0 - ([4d13b42](https://github.com/mumu-lhl/Ciyue/commit/4d13b428079a9244aa135dc5901e741bc35f6ffc)) - dependabot[bot]
- **(deps)** bump go_router from 14.8.1 to 15.0.0 - ([576f717](https://github.com/mumu-lhl/Ciyue/commit/576f717984cd6c4d152db00ef570c63c3d36edd4)) - dependabot[bot]
- **(deps-dev)** bump esbuild - ([acba5b3](https://github.com/mumu-lhl/Ciyue/commit/acba5b3905a17af9fc83fa65977869ea5b5fd8ed)) - dependabot[bot]
- **(deps-dev)** bump esbuild from 0.25.0 to 0.25.2 in /docs - ([c32bb8d](https://github.com/mumu-lhl/Ciyue/commit/c32bb8d8ce339002a0c428cffc32cd5e07a441bf)) - dependabot[bot]
- **(vitepress)** add esbuild as a devDependency in package.json - ([8689308](https://github.com/mumu-lhl/Ciyue/commit/868930801ce52fa545bb33da42b52afe18abda22)) - Mumulhl
- exclude directories from analyzer - ([09f055c](https://github.com/mumu-lhl/Ciyue/commit/09f055c52e2feaebaace89ee7ac74537c35089dc)) - Mumulhl
- add .gitignore to exclude node_modules and cache directories - ([b30ab8d](https://github.com/mumu-lhl/Ciyue/commit/b30ab8dc0c06812f4d2a2e21c41c9f44316157b8)) - Mumulhl

### Refactoring

- restructure model provider logic for better clarity and maintainability - ([ba8e6b4](https://github.com/mumu-lhl/Ciyue/commit/ba8e6b4dbf5dee9087e161f3f8a3cf5252c3d528)) - Mumulhl
- enhance AI model management with dynamic provider configuration - ([a9b1eb9](https://github.com/mumu-lhl/Ciyue/commit/a9b1eb9723accf4dc09881a12d5443c2845a1833)) - Mumulhl
- update GeminiProvider API URL handling and improve model selection logic in settings - ([a4352c8](https://github.com/mumu-lhl/Ciyue/commit/a4352c890d4ef4ad9e5c5532078c269874ddbeae)) - Mumulhl
- replace WebviewDisplay with WordDisplay for word detail view - ([12f108e](https://github.com/mumu-lhl/Ciyue/commit/12f108e2374217e01c5068d3c8fbae39052dfc71)) - Mumulhl

---
## [1.10.0](https://github.com/mumu-lhl/Ciyue/compare/v1.9.0..v1.10.0) - 2025-04-13

### Bug Fixes

- **(ui)** instantly update UI when deleting or auto-removing search terms - ([44f0275](https://github.com/mumu-lhl/Ciyue/commit/44f027574753486e6638eb52a1c039099c1a4c3d)) - Mumulhl

### Documentation

- **(README)** add contributing guidelines - ([ad785db](https://github.com/mumu-lhl/Ciyue/commit/ad785db144cfbdcc7541d10643bf67cd989fa706)) - Mumulhl

### Features

- **(translation)** translated using Weblate (Bengali) - ([a2f043b](https://github.com/mumu-lhl/Ciyue/commit/a2f043bb9a3133d72ff3f2aeb4ab0b68c133f357)) - Ekramul Reza
- add TabBar position setting - ([5b3936a](https://github.com/mumu-lhl/Ciyue/commit/5b3936a2b077e3834852cb89e11b9a795b4da80d)) - Mumulhl

### Miscellaneous Chores

- **(ci)** fix release - ([685ef82](https://github.com/mumu-lhl/Ciyue/commit/685ef820061b2368debdf5a9a7645f4bc4476e2e)) - Mumulhl
- **(release)** fix installer path in release workflow - ([360630c](https://github.com/mumu-lhl/Ciyue/commit/360630c93fb1a75052837c93c395f3d3acc2e10a)) - Mumulhl

### Refactoring

- **(ui)** make TabBar horizontally scrollable to prevent tab overflow when there are many dictionaries - ([09ba69d](https://github.com/mumu-lhl/Ciyue/commit/09ba69dfa6198859f14c848b2bd046b936111620)) - Mumulhl
- **(ui)** center align tabs in WebviewDisplay TabBar - ([be6147d](https://github.com/mumu-lhl/Ciyue/commit/be6147d05f396199ffd47a36838f4433076a4655)) - Mumulhl
- **(ui)** reorder TabBarPositionSelector in SettingsScreen - ([9b63e42](https://github.com/mumu-lhl/Ciyue/commit/9b63e4267be7e17c651a685240c7b8f72fc48bbc)) - Mumulhl
- copy files to support path on Android - ([839042e](https://github.com/mumu-lhl/Ciyue/commit/839042e98613bd407cb2b0637f3a28eccd845265)) - Mumulhl

### Style

- format code - ([24cca87](https://github.com/mumu-lhl/Ciyue/commit/24cca874c74b868b85f091dee956869b1811570e)) - Mumulhl

---
## [1.9.0](https://github.com/mumu-lhl/Ciyue/compare/v1.8.0..v1.9.0) - 2025-04-05

### Bug Fixes

- **(focus)** wrap IndexedStack pages with FocusScope to fix restoration - ([67eb625](https://github.com/mumu-lhl/Ciyue/commit/67eb625560fda5fffc64c9ed05c2c55d93267686)) - Mumulhl
- clear history - ([21983fe](https://github.com/mumu-lhl/Ciyue/commit/21983fe785c8ce1fb73b63af25bf8a4735f56bbc)) - Mumulhl
- search bar location, sidebar icon and more options button - ([cb70fac](https://github.com/mumu-lhl/Ciyue/commit/cb70fac156e8fa1015e130eab980c461ca79e32b)) - Mumulhl
- TabBarView - ([76a07c4](https://github.com/mumu-lhl/Ciyue/commit/76a07c439e4095f1b7249c426cdb6ca5e19ca8f8)) - Mumulhl
- catch error before running - ([9989e0f](https://github.com/mumu-lhl/Ciyue/commit/9989e0f11bddde8d3f1d2c34b9adbfe346607fbf)) - Mumulhl
- cannot running app after removing cache - ([4fa7458](https://github.com/mumu-lhl/Ciyue/commit/4fa7458377f62d82fc631ce6909b6c7f46f671df)) - Mumulhl

### Documentation

- add sponsors section to README files - ([c705273](https://github.com/mumu-lhl/Ciyue/commit/c705273938557d2319f2371eb2926f6cb9cc979f)) - Mumulhl

### Features

- **(l10n)** add AI prompt-related localization entries - ([ca62b2e](https://github.com/mumu-lhl/Ciyue/commit/ca62b2e6b0c6b3357a6f92cc0445bf8ed04d982f)) - Mumulhl
- **(language)** support Bengali language (Thanks to Ekramul Reza) - ([5e6f783](https://github.com/mumu-lhl/Ciyue/commit/5e6f783d95fe64fae0ef36067911c0d3c8090064)) - Mumulhl
- **(translation)** translated using Weblate (Sardinian) - ([9793191](https://github.com/mumu-lhl/Ciyue/commit/9793191866bd25431474cb109f2964b041755f33)) - Ajeje Brazorf
- **(translation)** added translation using Weblate (Bengali) - ([41cfd16](https://github.com/mumu-lhl/Ciyue/commit/41cfd1689b863a2ba6143f86e51911fffed85315)) - Ekramul Reza
- **(translation)** translated using Weblate (Bengali) - ([de3311e](https://github.com/mumu-lhl/Ciyue/commit/de3311e942eddcfb633206262728d7b1a8d70bb1)) - Ekramul Reza
- **(translation)** translated using Weblate (Bengali) - ([4741f4e](https://github.com/mumu-lhl/Ciyue/commit/4741f4e403ee74392c50b0729fb95f8387696a86)) - Ekramul Reza
- **(translation)** translated using Weblate (Bengali) - ([3d5e080](https://github.com/mumu-lhl/Ciyue/commit/3d5e0808ded778c5eec8b84e09d26dae224759fa)) - Ekramul Reza
- support navigation rail - ([b2818bb](https://github.com/mumu-lhl/Ciyue/commit/b2818bb8ff0351f11fc6693de46a82aed92c8838)) - Mumulhl
- add error handling and reporting UI before running - ([6629664](https://github.com/mumu-lhl/Ciyue/commit/6629664495c5ea99a6d845ec060b490f83e7a338)) - Mumulhl
- support custom prompts - ([871bfca](https://github.com/mumu-lhl/Ciyue/commit/871bfcae3f6540a2eceec0427d642876cd9b3950)) - Mumulhl

### Miscellaneous Chores

- **(ci)** prevent double zipping of Windows build artifact - ([eaaaaac](https://github.com/mumu-lhl/Ciyue/commit/eaaaaac71e1d05869d46dbc8cec049698fc07011)) - Mumulhl
- **(ci)** prevent double zipping of Linux build artifact - ([e6d6b7a](https://github.com/mumu-lhl/Ciyue/commit/e6d6b7a57046f94cc3d25b6efb2ade017dd8d8f7)) - Mumulhl
- **(ci)** fix linux build - ([b8a3ac0](https://github.com/mumu-lhl/Ciyue/commit/b8a3ac0483d42b993b76b0b19f89831120d5369b)) - Mumulhl
- **(deps)** bump shared_preferences from 2.5.2 to 2.5.3 - ([aff9641](https://github.com/mumu-lhl/Ciyue/commit/aff96410ae50c4c3012d55a61ed997056c97c0ef)) - dependabot[bot]
- **(release)** add windows installer - ([b1545a4](https://github.com/mumu-lhl/Ciyue/commit/b1545a4cf3f3e743c34a1bdbc722688d86b578be)) - Mumulhl
- **(release)** include installer executable in release artifacts - ([6cb7304](https://github.com/mumu-lhl/Ciyue/commit/6cb73040e98d97ab8befaa0c0cea881941a623b3)) - Mumulhl

### Refactoring

- replace context.select with Consumer - ([5173ef5](https://github.com/mumu-lhl/Ciyue/commit/5173ef5bb91cca89c468fcb4c24f4007eb6a7c35)) - Mumulhl
- constrain maximum width in settings, auto export and dictionary management pages - ([e2ad4b3](https://github.com/mumu-lhl/Ciyue/commit/e2ad4b3e58b336ea3a8336341e3ce1b718eaba73)) - Mumulhl
- add DictManagerModel for managing dictionary groups and integrate with HomeModel - ([a00d707](https://github.com/mumu-lhl/Ciyue/commit/a00d707c78a3266e8c8728230ce4f352768ee4b3)) - Mumulhl
- refactor TextField - ([59aeff0](https://github.com/mumu-lhl/Ciyue/commit/59aeff0e6dc7d7f2e8bf07f35a3e16a5070ebe40)) - Mumulhl

---
## [1.8.0](https://github.com/mumu-lhl/Ciyue/compare/v1.7.0..v1.8.0) - 2025-03-30

### Bug Fixes

- fix remove single history twice - ([b69c342](https://github.com/mumu-lhl/Ciyue/commit/b69c3420120d2aa4e5d7feecfddfd5437409c098)) - Mumulhl

### Features

- **(model)** add Gemini 2.5 Pro - ([5a3638f](https://github.com/mumu-lhl/Ciyue/commit/5a3638f8bc1baf02e8d415482d981a8bcaef1090)) - Mumulhl
- **(translation)** added translation using Weblate (Spanish) - ([809dfca](https://github.com/mumu-lhl/Ciyue/commit/809dfcae38a93b598030f60d5bfe02889cabd897)) - Elías Fuentes
- **(translation)** translated using Weblate (Spanish) - ([b68b2b9](https://github.com/mumu-lhl/Ciyue/commit/b68b2b95d0de18048d4c7ca97fb5678e165dec3b)) - Elías Fuentes
- **(translation)** translated using Weblate (Russian) - ([57e5e43](https://github.com/mumu-lhl/Ciyue/commit/57e5e4366b7b2cf92a465e224d31de09f6914381)) - Xapitonov
- **(translation)** translated using Weblate (Russian) - ([4db47c5](https://github.com/mumu-lhl/Ciyue/commit/4db47c5c8cfb243ad903e37f161f0e33485ed830)) - Xapitonov
- **(translation)** update Spanish localization with new strings - ([379e3e2](https://github.com/mumu-lhl/Ciyue/commit/379e3e249ad45cd81034743510ef0839ec73fa15)) - Mumulhl
- support Spanish - ([aa16dbd](https://github.com/mumu-lhl/Ciyue/commit/aa16dbdb507e69790ee9d7d84836b6e55b5578e6)) - Mumulhl

### Refactoring

- refactor the code of home - ([eaeb141](https://github.com/mumu-lhl/Ciyue/commit/eaeb141c8cd4932380bea84482744e5ef710e7ad)) - Mumulhl
- refactor main page and history list - ([a332152](https://github.com/mumu-lhl/Ciyue/commit/a3321524b1bc52693604303e8f66bb321f9cd612)) - Mumulhl
- refactor wordbook state management - ([05327ec](https://github.com/mumu-lhl/Ciyue/commit/05327ec6177f983d168fb0dfc044a76458ec8f8e)) - Mumulhl
- streamline variable declarations in AiTranslatePage - ([fea31a7](https://github.com/mumu-lhl/Ciyue/commit/fea31a72d846875b8c311c7493179e6c29a2709b)) - Mumulhl
- improve performance - ([6dd2237](https://github.com/mumu-lhl/Ciyue/commit/6dd2237e350c5a88e0e0be2cefe9dd9ee02454f5)) - Mumulhl
- refactor home state management - ([cdf19d0](https://github.com/mumu-lhl/Ciyue/commit/cdf19d051531a7039c09db3386e1b93b290f1358)) - Mumulhl

### Style

- format code - ([76fdf44](https://github.com/mumu-lhl/Ciyue/commit/76fdf44ec11ace4e473a8b9e722110156dcef19c)) - Mumulhl
- format code - ([b880de1](https://github.com/mumu-lhl/Ciyue/commit/b880de161fc1f3a742eb0bffcc1941812aa83666)) - Mumulhl

---
## [1.7.0](https://github.com/mumu-lhl/Ciyue/compare/v1.7.0-beta.1..v1.7.0) - 2025-03-23

### Bug Fixes

- update translate label to use localization - ([09ee403](https://github.com/mumu-lhl/Ciyue/commit/09ee403dc3a497e27cb6dc22548bbd5f15255d9c)) - Mumulhl
- blank screen when editing title alias of a disabled dict - ([95f41b0](https://github.com/mumu-lhl/Ciyue/commit/95f41b01493d96e55211a9f459ceac65a1079543)) - Mumulhl
- fix importing - ([f002509](https://github.com/mumu-lhl/Ciyue/commit/f0025095466ec864a65bf452c5aae76300dbce4d)) - Mumulhl
- update language labels and adjust AI explain settings - ([324383b](https://github.com/mumu-lhl/Ciyue/commit/324383bdae2e2e3296c648079de77e10c605b965)) - Mumulhl

### Documentation

- add GitHub badge to installation section in README files - ([5f713f7](https://github.com/mumu-lhl/Ciyue/commit/5f713f71a9d9dba6e609e0a0ab285837aebb7ee5)) - Mumulhl
- add AI translate feature to README - ([d833b18](https://github.com/mumu-lhl/Ciyue/commit/d833b1818088f535ed0553929ef231c55451aa27)) - Mumulhl
- update README to clarify MDX/MDD support on Linux - ([f91bf20](https://github.com/mumu-lhl/Ciyue/commit/f91bf20aba54661159fc0dc076c2c483bd3cb14e)) - Mumulhl
- add Privacy Policy, Terms and Disclaimer of Service to documentation - ([520b896](https://github.com/mumu-lhl/Ciyue/commit/520b8963a502d9c9883b91db7303758c93b94bf9)) - Mumulhl
- update screenshots - ([3940bcb](https://github.com/mumu-lhl/Ciyue/commit/3940bcb469d08405bde9f355f435c5187edc7a98)) - Mumulhl

### Features

- **(AIExplain)** dynamically set output language based on user settings - ([af088e5](https://github.com/mumu-lhl/Ciyue/commit/af088e5c61b8559cc479881adbb61c4bae424711)) - Mumulhl
- **(l10n)** add update-related translations for multiple languages - ([bc1c281](https://github.com/mumu-lhl/Ciyue/commit/bc1c281ba8288e06bc5489747f3432d8acb2c87e)) - Mumulhl
- **(translation)** translated using Weblate (English) - ([cc79d77](https://github.com/mumu-lhl/Ciyue/commit/cc79d773b3117fc6fd2bbe09fb50eb75ce371047)) - Allan Nordhøy
- allow multi-line input for text translation - ([d561011](https://github.com/mumu-lhl/Ciyue/commit/d5610113a1e9513d9a5d0d50f97e062a4216a875)) - Mumulhl
- make markdown widget scrollable - ([45e3184](https://github.com/mumu-lhl/Ciyue/commit/45e31846e5b23f8cd4125c330950ebc6596330dd)) - Mumulhl
- add titles to Privacy Policy and Terms of Service pages - ([0c5bcae](https://github.com/mumu-lhl/Ciyue/commit/0c5bcaebb37289a311c7aaea0acda761a2d92b55)) - Mumulhl
- enable explain word - ([8e455bd](https://github.com/mumu-lhl/Ciyue/commit/8e455bdf1e0005bce96846f7ffe6c58b96b4c30c)) - Mumulhl
- hide the tab when only one dictionary is available - ([e4cd0e0](https://github.com/mumu-lhl/Ciyue/commit/e4cd0e0602c8d4298f22d3ef3320669b0e545a1f)) - Mumulhl
- add AI Explain Word feature - ([90d9416](https://github.com/mumu-lhl/Ciyue/commit/90d9416bc1296714333fbb40e61bb9c5605c4609)) - Mumulhl
- add check for updates functionality in settings - ([f0a0183](https://github.com/mumu-lhl/Ciyue/commit/f0a0183975e85f6648efa8d52320ce6b06648b85)) - Mumulhl
- add option to include prerelease updates in settings - ([2c25149](https://github.com/mumu-lhl/Ciyue/commit/2c25149ee577af574371339902bc82c289334dc7)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump flutter_local_notifications from 18.0.1 to 19.0.0 - ([e6a9364](https://github.com/mumu-lhl/Ciyue/commit/e6a936466d95f01cbb3e9b1a8ffd9ededa191ca0)) - dependabot[bot]
- **(deps)** replace flutter_markdown with gpt_markdown - ([717feef](https://github.com/mumu-lhl/Ciyue/commit/717feef68e970994a7473910fe556141814acdf2)) - Mumulhl
- add flutter_local_notifications_windows to FFI plugin list - ([0a62e7c](https://github.com/mumu-lhl/Ciyue/commit/0a62e7c6674f28046a16a4186be34d3b95c11fe5)) - Mumulhl
- update package description to include Windows/Linux support - ([b0ecb0b](https://github.com/mumu-lhl/Ciyue/commit/b0ecb0b85cf102343ff423814e6a124db753e816)) - Mumulhl

### Refactoring

- keep AiTranslatePage state - ([cfee517](https://github.com/mumu-lhl/Ciyue/commit/cfee517abedb193ebebfd881523ba7c757d0e43e)) - Mumulhl
- update input handling to use TextEditingController for translation - ([321ef49](https://github.com/mumu-lhl/Ciyue/commit/321ef49dcf472247e540058716b09cc477a48e4c)) - Mumulhl
- move _isRichOutput variable declaration to the top level - ([23b44b1](https://github.com/mumu-lhl/Ciyue/commit/23b44b1272153a44989c1a22b58d7398064d5069)) - Mumulhl

### Style

- format code - ([c1d93e0](https://github.com/mumu-lhl/Ciyue/commit/c1d93e0c2f1ad8f3befa1aea6a228ef1f8523688)) - Mumulhl

---
## [1.7.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.6.0..v1.7.0-beta.1) - 2025-03-16

### Bug Fixes

- open privacy policy - ([f8b488f](https://github.com/mumu-lhl/Ciyue/commit/f8b488f89827111f8dc2899ff8aa9674c2f8f77b)) - Mumulhl
- fix model name - ([0f0cc48](https://github.com/mumu-lhl/Ciyue/commit/0f0cc481477971ec8a00a4154d885113e92365a1)) - Mumulhl

### Documentation

- update multi-platform support to README - ([89c6b38](https://github.com/mumu-lhl/Ciyue/commit/89c6b38ac23ee6ea2556200868a5931c0372f913)) - Mumulhl

### Features

- **(l10n)** add auto detect - ([a015c4c](https://github.com/mumu-lhl/Ciyue/commit/a015c4c73aa98fc44e1ce1462fbd1d28d6bb03c1)) - Mumulhl
- **(l10n)** add new translation - ([26bfa79](https://github.com/mumu-lhl/Ciyue/commit/26bfa796384fb3f90d4d39c6032b3dff739ec69b)) - Mumulhl
- **(translation)** translated using Weblate (Chinese (Traditional Han script)) - ([5a51678](https://github.com/mumu-lhl/Ciyue/commit/5a51678e51757bfc1396bd7d495c257a60d0ed6d)) - plum7x
- **(translation)** translated using Weblate (English) - ([d93a5f0](https://github.com/mumu-lhl/Ciyue/commit/d93a5f0bc90dc8c01398162ebd88f1f355047080)) - Integral
- **(translation)** translated using Weblate (Chinese (Simplified Han script)) - ([b3e7706](https://github.com/mumu-lhl/Ciyue/commit/b3e770675d3f508dd57a0737728fbb5d2cd2a312)) - Integral
- **(translation)** translated using Weblate (Chinese (Traditional Han script, Hong Kong)) - ([d0f5042](https://github.com/mumu-lhl/Ciyue/commit/d0f50420adf8fb1aa448157f91baf42290c38818)) - Integral
- **(translation)** translated using Weblate (Norwegian Bokmål) - ([6b3044f](https://github.com/mumu-lhl/Ciyue/commit/6b3044fd1ff4f3dc26bc403b974d407154467c8a)) - Integral
- **(translation)** translated using Weblate (Russian) - ([7bdfde2](https://github.com/mumu-lhl/Ciyue/commit/7bdfde2819f2c362b2bf6dccfc54e9cf722e689d)) - Integral
- **(translation)** translated using Weblate (Sardinian) - ([835dbca](https://github.com/mumu-lhl/Ciyue/commit/835dbcab468527280b53ecba9fba6c99d9afd5c1)) - Integral
- **(translation)** translated using Weblate (Tamil) - ([741f7ea](https://github.com/mumu-lhl/Ciyue/commit/741f7ea0dceb5389372b5ce8041fe4e1360aafbf)) - Integral
- **(translation)** translated using Weblate (Persian) - ([2ddabc4](https://github.com/mumu-lhl/Ciyue/commit/2ddabc4c11a8b4e44f366d0ada8da5a48ba1d533)) - Integral
- **(translation)** translated using Weblate (German) - ([48eb51d](https://github.com/mumu-lhl/Ciyue/commit/48eb51d86215ca9c1b259672dbdde58a90c48968)) - Integral
- add AI Settings page - ([971c6ea](https://github.com/mumu-lhl/Ciyue/commit/971c6ea375e4d6fa56ef1736b8d7d09ceb5885af)) - Mumulhl
- implement AI configuration - ([2d00106](https://github.com/mumu-lhl/Ciyue/commit/2d0010653417d777a482e9916a05c758ee498544)) - Mumulhl
- enhance AI model selection with detailed model information - ([e74f3ac](https://github.com/mumu-lhl/Ciyue/commit/e74f3ac4b72cb40e253ac67df708348b80f5c356)) - Mumulhl
- add AI Explain Word settings - ([605497a](https://github.com/mumu-lhl/Ciyue/commit/605497a5f0701140cdafe1f305ab6d8650d170df)) - Mumulhl
- implement AI provider classes for OpenAI and Gemini APIs - ([ff31cf5](https://github.com/mumu-lhl/Ciyue/commit/ff31cf529889e7b538e9feead2cd3b43b1d2efe1)) - Mumulhl
- update OpenAI provider to support compatible API URL and rename class - ([36ddcc3](https://github.com/mumu-lhl/Ciyue/commit/36ddcc32a8ca7636e170c072653d10d413e54353)) - Mumulhl
- add AI translate feature - ([908b767](https://github.com/mumu-lhl/Ciyue/commit/908b767b4b7d2b1a72ff2dcb80df6287dbc13d54)) - Mumulhl
- add Privacy Policy - ([6e7e3fa](https://github.com/mumu-lhl/Ciyue/commit/6e7e3fa9cddb69caec1842944ef442881b3784b9)) - Mumulhl
- add synthetic-package configuration to l10n.yaml - ([5c5dd50](https://github.com/mumu-lhl/Ciyue/commit/5c5dd50f2440059e1ec454d5a5cd11669bcc1c80)) - Mumulhl
- add Terms of Service - ([5e4b282](https://github.com/mumu-lhl/Ciyue/commit/5e4b28217fcf5827318f4f000c71864d1de7ec49)) - Mumulhl
- add more languages in Translate - ([35189a1](https://github.com/mumu-lhl/Ciyue/commit/35189a19b7443f408cb4a6e6bdd616df405ae049)) - Mumulhl
- support Deepseek - ([52984b2](https://github.com/mumu-lhl/Ciyue/commit/52984b280a2d072d9fd740d791f970b9369979c2)) - Mumulhl
- support Authropic - ([c3f5419](https://github.com/mumu-lhl/Ciyue/commit/c3f5419dc5326490794ef5eadb255d4559caaea0)) - Mumulhl

### Miscellaneous Chores

- **(ci)** add Linux build to workflow - ([a7754e6](https://github.com/mumu-lhl/Ciyue/commit/a7754e69f4cc075c27db4632a768b8ec9677028d)) - Integral
- **(ci)** update flutter version - ([b51d946](https://github.com/mumu-lhl/Ciyue/commit/b51d946ef5ffb77f20958e555a6df99ed7bfc9d3)) - Mumulhl
- **(ci)** fix ci - ([b9bff36](https://github.com/mumu-lhl/Ciyue/commit/b9bff36790ab6b416fe8afa44f4e6df8c15ef54e)) - Mumulhl
- **(ci)** remove redundant localization generation steps from workflows - ([cad997d](https://github.com/mumu-lhl/Ciyue/commit/cad997dc7bd0b461f0a428348de4f0cba8e601bf)) - Mumulhl
- **(ci)** fix ci - ([e7bf648](https://github.com/mumu-lhl/Ciyue/commit/e7bf648a0e74f5c62e115a8af636219c7bdc6c65)) - Mumulhl
- **(deps)** bump drift from 2.25.1 to 2.26.0 - ([0616e0d](https://github.com/mumu-lhl/Ciyue/commit/0616e0d537b9b7b6d90ccb74db89ce5c4b0b12d5)) - dependabot[bot]
- update package versions and sha256 checksums in pubspec.lock - ([5f7b305](https://github.com/mumu-lhl/Ciyue/commit/5f7b305f1da4e9e20a8f2b0d80d6499cc43283de)) - Mumulhl
- update pubspec.lock and l10n - ([d3a1c69](https://github.com/mumu-lhl/Ciyue/commit/d3a1c69d33d2cc1096f5e4cd568c3a2078e3de95)) - Mumulhl
- add generated files .gitignore - ([b67670b](https://github.com/mumu-lhl/Ciyue/commit/b67670b6e66c398f31bbfd958c7380c3df3efcc7)) - Mumulhl

### Refactoring

- **(ui)** improve layout of privacy policy page for better readability - ([ad1b4a9](https://github.com/mumu-lhl/Ciyue/commit/ad1b4a9ed71183df8b3ff4a14b0b2c37e0f1d90b)) - Mumulhl
- **(ui)** center and constrain layout of AI Translate page for improved presentation - ([02d40b0](https://github.com/mumu-lhl/Ciyue/commit/02d40b0478fe84a21418b7d855d88f88f2fc662c)) - Mumulhl
- move files to settings directory - ([c862c7d](https://github.com/mumu-lhl/Ciyue/commit/c862c7d66130daedb6b803ff4aa6770025cc9d2c)) - Mumulhl
- update default model in AI provider config - ([cb1eb04](https://github.com/mumu-lhl/Ciyue/commit/cb1eb045dfa0bfbe10caa6018a01b01ea8497ff4)) - Mumulhl
- refactor AI provider initialization and translate languages - ([c8d5216](https://github.com/mumu-lhl/Ciyue/commit/c8d5216a448a933bc44b8f544b66951838a6724b)) - Mumulhl
- disable ai explain word switch - ([b548366](https://github.com/mumu-lhl/Ciyue/commit/b54836622888411716c85176bba7f185ad99c31a)) - Mumulhl

### Style

- format code - ([f672327](https://github.com/mumu-lhl/Ciyue/commit/f672327356f6130e31a7a30a36346872263ff2bc)) - Mumulhl
- format code - ([f0ef90e](https://github.com/mumu-lhl/Ciyue/commit/f0ef90ecd0340de70e454a6ece789d0fcd56a31f)) - Mumulhl
- format code - ([e16b801](https://github.com/mumu-lhl/Ciyue/commit/e16b801090e9a05813d62552b7660860957b2d07)) - Mumulhl

---
## [1.6.0](https://github.com/mumu-lhl/Ciyue/compare/v1.5.0..v1.6.0) - 2025-03-09

### Bug Fixes

- fix word's date in wordbook - ([382d01d](https://github.com/mumu-lhl/Ciyue/commit/382d01d3bf2192e7946a49e18f3af73b8dcf5a55)) - Mumulhl
- filter duplicate search results - ([dcb6a1c](https://github.com/mumu-lhl/Ciyue/commit/dcb6a1ceead81de7a012cab001df8b4ee70cf460)) - Mumulhl
- fix Sardinian - ([6595f51](https://github.com/mumu-lhl/Ciyue/commit/6595f51dbd490f9e89a45193c7e8c8ec00c47f48)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump path from 1.9.0 to 1.9.1 - ([2c63401](https://github.com/mumu-lhl/Ciyue/commit/2c63401124852ba1cd869e24238ebeaac14e1ff3)) - dependabot[bot]
- **(deps)** bump package_info_plus from 8.2.1 to 8.3.0 - ([367e739](https://github.com/mumu-lhl/Ciyue/commit/367e7390bfdf682740730a7f016caa51cdab46b3)) - dependabot[bot]
- **(deps)** bump go_router from 14.8.0 to 14.8.1 - ([b0aa59c](https://github.com/mumu-lhl/Ciyue/commit/b0aa59c5e7c064ba9837d760743664c64bfcdf62)) - dependabot[bot]
- **(deps)** downgrade path package - ([7e07a16](https://github.com/mumu-lhl/Ciyue/commit/7e07a16e52e52cf286700055ee2f3ddfbd1e95a7)) - Mumulhl

### Refactoring

- **(ui)** refactor dynamic color - ([3f11fa8](https://github.com/mumu-lhl/Ciyue/commit/3f11fa88a7ced05dd0588054c6ae0b41f32cea19)) - Mumulhl
- update class name - ([1ec4d3a](https://github.com/mumu-lhl/Ciyue/commit/1ec4d3acae876a5efe8cb38cbaa71067c6ef67a7)) - Mumulhl
- show more recommended dictionaries - ([b2278da](https://github.com/mumu-lhl/Ciyue/commit/b2278daaf2db71241ce11978b0c59fbba9aac5f0)) - Mumulhl

### Tests

- fix schema test - ([ed7c681](https://github.com/mumu-lhl/Ciyue/commit/ed7c681bda08e30151a95cbd0fa5f103ba3cea2d)) - Mumulhl

---
## [1.5.0](https://github.com/mumu-lhl/Ciyue/compare/v1.4.0..v1.5.0) - 2025-03-02

### Bug Fixes

- context menu search doesn't work with capitalized word - ([bb8bb55](https://github.com/mumu-lhl/Ciyue/commit/bb8bb5569adbc27b167a07a701a35d1e820cd9ba)) - Mumulhl
- fix sort with date filtering - ([7b813c1](https://github.com/mumu-lhl/Ciyue/commit/7b813c149a7da4050868ae626ece76ddbf76314e)) - Mumulhl

### Features

- **(i10n)** finish i10n - ([d6562c0](https://github.com/mumu-lhl/Ciyue/commit/d6562c0ede691f46d03d60959226a76f20f2331b)) - Mumulhl
- **(ui)** group settings - ([d8e7399](https://github.com/mumu-lhl/Ciyue/commit/d8e7399696e4122c9eb15ef0b678dfacd1e3ceea)) - Mumulhl
- add words to the wordbook with the date - ([56bbd0b](https://github.com/mumu-lhl/Ciyue/commit/56bbd0bb025b322575088d9d9568ff303a3115f0)) - Mumulhl
- show date of words - ([732e277](https://github.com/mumu-lhl/Ciyue/commit/732e277f2eabf96e064a6273799ce46ef6deecba)) - Mumulhl
- allow selecting date for filtering words - ([d2d4679](https://github.com/mumu-lhl/Ciyue/commit/d2d46795757822d412cc90d75f70f02e30620cb3)) - Mumulhl

### Miscellaneous Chores

- add shared_preferences to devtools - ([3ea4827](https://github.com/mumu-lhl/Ciyue/commit/3ea4827501200caeb634634bf6f6f798895f708c)) - Mumulhl

### Refactoring

- **(ui)** improve ui - ([3ae0548](https://github.com/mumu-lhl/Ciyue/commit/3ae05483a936d894c32359c89d63a8a85099d772)) - Mumulhl
- rename file and class - ([becc956](https://github.com/mumu-lhl/Ciyue/commit/becc95692f49fcd880f54cd6b1982f7c6a8b337b)) - Mumulhl
- improve performance - ([c49bac8](https://github.com/mumu-lhl/Ciyue/commit/c49bac87a48088da8269a3951e84997865c9aea2)) - Mumulhl

### Style

- format code - ([432cdd4](https://github.com/mumu-lhl/Ciyue/commit/432cdd40452c16bc5c09f41230a07029d7a36b6e)) - Mumulhl

---
## [1.4.0](https://github.com/mumu-lhl/Ciyue/compare/v1.3.1..v1.4.0) - 2025-02-23

### Bug Fixes

- handle empty values in tagsOrder parsing - ([8ba2c8e](https://github.com/mumu-lhl/Ciyue/commit/8ba2c8ede1deb3ca16cfb04eabfcff7ef254e698)) - Mumulhl
- check for existing tags during initialization - ([d7d0af3](https://github.com/mumu-lhl/Ciyue/commit/d7d0af3488fa48b8343f91535c3fb22f387f434b)) - Mumulhl
- fix long press on dictionary card non-selected - ([b62c911](https://github.com/mumu-lhl/Ciyue/commit/b62c911cf75e726d0d82c4702148a8aacfc50e6a)) - Mumulhl
- fix escape string in dictionary title - ([abbd274](https://github.com/mumu-lhl/Ciyue/commit/abbd2745484a8d4a0e5cf2d53919092c7c067a0b)) - Mumulhl
- display title when title in header is empty string - ([18f6692](https://github.com/mumu-lhl/Ciyue/commit/18f6692adcf5891e1e3f8aa4e61c777cc22345c7)) - Mumulhl

### Documentation

- **(README)** add Discord server link to README - ([2013cdf](https://github.com/mumu-lhl/Ciyue/commit/2013cdfdc4aa2210c96cbf7459c02b9f876ccec8)) - Mumulhl
- **(README)** fix typo - ([7efa873](https://github.com/mumu-lhl/Ciyue/commit/7efa873e56ef29614f89e70481a5837acae8607b)) - Mumulhl

### Features

- support selecting tags for adding words to wordbook at home page - ([3af1a3b](https://github.com/mumu-lhl/Ciyue/commit/3af1a3b058ab85c45006080585fda5432f649b4c)) - Mumulhl
- add dictionary groups localization for multiple languages - ([e664960](https://github.com/mumu-lhl/Ciyue/commit/e6649606d18769eb0d510ab16f4e1ccfb635c9e8)) - Mumulhl
- add Discord link - ([91ed205](https://github.com/mumu-lhl/Ciyue/commit/91ed20531ac5cf036a02a5ead03bf386ad078676)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump path from 1.9.0 to 1.9.1 - ([c6beb76](https://github.com/mumu-lhl/Ciyue/commit/c6beb7602606e3fef87c6558d839f60f7703a648)) - dependabot[bot]
- **(deps)** bump shared_preferences from 2.5.1 to 2.5.2 - ([b8c1ac6](https://github.com/mumu-lhl/Ciyue/commit/b8c1ac6ceb7e0a34b0e9d7de1998d910dc3aaf3e)) - dependabot[bot]
- **(deps)** bump test from 1.25.8 to 1.25.15 - ([097f481](https://github.com/mumu-lhl/Ciyue/commit/097f481ba5f28806d6708d52b4355cc65deba26b)) - dependabot[bot]
- **(deps)** bump drift from 2.25.0 to 2.25.1 - ([e58e811](https://github.com/mumu-lhl/Ciyue/commit/e58e8119ad55a07d40a8622a91fb98008bc8c6c0)) - dependabot[bot]
- **(deps)** bump build_runner from 2.4.14 to 2.4.15 - ([25a91ca](https://github.com/mumu-lhl/Ciyue/commit/25a91caee4c2a9c24d98b88a935cf666c858de70)) - dependabot[bot]
- **(deps)** downgrade dependencies in pubspec.lock and pubspec.yaml - ([32ceecf](https://github.com/mumu-lhl/Ciyue/commit/32ceecf9e4d92fd5a9a931fdb1ff3f929fa80378)) - Mumulhl

### Refactoring

- **(ui)** Ink Well animation with rounded corners - ([3d11791](https://github.com/mumu-lhl/Ciyue/commit/3d11791e149ff96d5c10a705e688f37b1866f0e8)) - Mumulhl
- remove useless comment - ([fee2c57](https://github.com/mumu-lhl/Ciyue/commit/fee2c57ec414aa4f89605ebb6f163b5398d3b9dd)) - Mumulhl
- simplify code - ([d58a760](https://github.com/mumu-lhl/Ciyue/commit/d58a7604d8592195978b677d4aa31616dbeaa655)) - Mumulhl
- don't show not found dictionaries defaultly - ([9e3421e](https://github.com/mumu-lhl/Ciyue/commit/9e3421eabf406826030199577832bb615f77361b)) - Mumulhl

### Revert

- "Merge pull request #178 from mumu-lhl/fix-171" - ([cc4e4db](https://github.com/mumu-lhl/Ciyue/commit/cc4e4dbf1942dc8df8d170cceb1892da6d1378d5)) - Mumulhl

### Style

- format code - ([589161e](https://github.com/mumu-lhl/Ciyue/commit/589161e580908a492ff12bcccf95b457b684d46a)) - Mumulhl
- improve search bar padding and update home page list item layout - ([3482f5a](https://github.com/mumu-lhl/Ciyue/commit/3482f5a4a77e99a3c956bd592b7dce360bc989eb)) - Mirpri
- format code - ([86ff393](https://github.com/mumu-lhl/Ciyue/commit/86ff393a62a206781711357dc4e53f97afaa2f9f)) - Mumulhl
- format code - ([14cb465](https://github.com/mumu-lhl/Ciyue/commit/14cb465be4a1ff7ef225af196c167c1842a0e746)) - Mumulhl
- add comment - ([216332e](https://github.com/mumu-lhl/Ciyue/commit/216332e7b0e55169daa99e9df627c7d9ee7a3e58)) - Mumulhl

---
## [1.3.1](https://github.com/mumu-lhl/Ciyue/compare/v1.3.0..v1.3.1) - 2025-02-16

### Bug Fixes

- handle empty values in tags order parsing - ([78be19c](https://github.com/mumu-lhl/Ciyue/commit/78be19c3908d7fa9cc66566206997f943e96a33e)) - Mumulhl
- optimize word addition logic - ([6c6f035](https://github.com/mumu-lhl/Ciyue/commit/6c6f035eae7965e92551f4e080e4901e582197c4)) - Mumulhl

### Miscellaneous Chores

- **(deps)** update package_info_plus and timezone versions - ([fd2b7a2](https://github.com/mumu-lhl/Ciyue/commit/fd2b7a26a6d4d7f99ab60622abed5740ee862543)) - Mumulhl
- **(deps)** bump drift from 2.24.0 to 2.25.0 - ([430f69b](https://github.com/mumu-lhl/Ciyue/commit/430f69bd99e249bc06269a4700945e7694247ad8)) - dependabot[bot]
- **(deps)** bump package_info_plus from 8.2.0 to 8.2.1 - ([c17d963](https://github.com/mumu-lhl/Ciyue/commit/c17d96325b96f2b22c0bbb123cc5a117ed2b50aa)) - dependabot[bot]
- **(deps)** bump go_router from 14.7.2 to 14.8.0 - ([6187b96](https://github.com/mumu-lhl/Ciyue/commit/6187b96234a3c5c6b9c0a983e97eb202eb778bd1)) - dependabot[bot]
- **(deps)** bump drift_dev from 2.25.0 to 2.25.2 - ([1bb0d5c](https://github.com/mumu-lhl/Ciyue/commit/1bb0d5c52147f9fd35dabfc56024b64a0ffd24dd)) - dependabot[bot]
- add memory-bank directory to .gitignore - ([9238c54](https://github.com/mumu-lhl/Ciyue/commit/9238c540df9454288104bc2332a6c4709af24cd6)) - Mumulhl

### Refactoring

- don't show empty text when tags is valid - ([fe8b904](https://github.com/mumu-lhl/Ciyue/commit/fe8b9042de82996e2292ef70306c8c896293ea3a)) - Mumulhl

---
## [1.3.0](https://github.com/mumu-lhl/Ciyue/compare/v1.2.0..v1.3.0) - 2025-02-07

### Bug Fixes

- fix deleting dictionary - ([ed277a0](https://github.com/mumu-lhl/Ciyue/commit/ed277a0e12d9b12e63f2e460738a0ee55c6fa22f)) - Mumulhl
- fix export feature on Windows - ([faef218](https://github.com/mumu-lhl/Ciyue/commit/faef218f58c879e19f631c30856f8bdd1f433138)) - Mumulhl
- fix auto export feature on Windows - ([424c968](https://github.com/mumu-lhl/Ciyue/commit/424c968a3928baab0d3ac8a022b667e653ff14f5)) - Mumulhl
- show bottom search bar on wrongly screens - ([900c8fd](https://github.com/mumu-lhl/Ciyue/commit/900c8fdcb6a0f10ed9f8e6c2c9cbc093c712a5c1)) - Mumulhl
- show more options button - ([4194f64](https://github.com/mumu-lhl/Ciyue/commit/4194f64491c2f653575fbf7302f76bd5bd66bbc0)) - Mumulhl

### Features

- disable SecureScreen on Windows - ([ce385bc](https://github.com/mumu-lhl/Ciyue/commit/ce385bc5d66f8bbdf548fe90cc0c6a74c06cca46)) - Mumulhl
- allow edit word when views word from process text - ([8e6c697](https://github.com/mumu-lhl/Ciyue/commit/8e6c69727ae65ae424316ae31cd6653517e0a847)) - Mumulhl
- enable autofocus on search field when a word is provided - ([81e67cd](https://github.com/mumu-lhl/Ciyue/commit/81e67cd671c941971a288f5f44cb66c4678d8292)) - Mumulhl
- add German and Sardinian language options to settings - ([5ce23d8](https://github.com/mumu-lhl/Ciyue/commit/5ce23d86fc2e66ae7cbc2891aa0f6f8d524aa2a0)) - Mumulhl
- add notification for searching fastly - ([717f2e4](https://github.com/mumu-lhl/Ciyue/commit/717f2e4d086ed2f2e1a893ab82e3e2faa7231d44)) - Mumulhl
- add more options button switch - ([d5e8c9a](https://github.com/mumu-lhl/Ciyue/commit/d5e8c9a9037157de00e9cb3326fea0e0d55a51ee)) - Mumulhl
- add title alias - ([214e01d](https://github.com/mumu-lhl/Ciyue/commit/214e01d94ed9f0ff5e26604e7ee8bb7acd222204)) - Mumulhl
- add option to skip tagged words in word book - ([cd0fd41](https://github.com/mumu-lhl/Ciyue/commit/cd0fd4157ebb0ddd2c934d1f13371858e0266c9d)) - Mumulhl
- add option to switch show not found words - ([75e33ca](https://github.com/mumu-lhl/Ciyue/commit/75e33ca81b9a21c8ed7db35c7fe92927da6ec5c7)) - Mumulhl

### Miscellaneous Chores

- **(ci)** update flutter version - ([fb47435](https://github.com/mumu-lhl/Ciyue/commit/fb4743532a130667fd706ed8cf9170dfd37f0b5d)) - Mumulhl

### Refactoring

- improve title alias handling - ([f6804cf](https://github.com/mumu-lhl/Ciyue/commit/f6804cf63c2c71f7e8eaf04204c81ebd23943b9c)) - Mumulhl

### Style

- format code - ([2540667](https://github.com/mumu-lhl/Ciyue/commit/25406679e16f1d62859e30ec35c932eb0fddf6e4)) - Mumulhl
- format code - ([bdeae82](https://github.com/mumu-lhl/Ciyue/commit/bdeae82d1e38347680f620ddee8af4a4e05ac871)) - Mumulhl
- format code - ([c2214a5](https://github.com/mumu-lhl/Ciyue/commit/c2214a59fd4f99ea9110b5219c3d5eb589db7d5a)) - Mumulhl
- format code - ([baccc83](https://github.com/mumu-lhl/Ciyue/commit/baccc83b5893d172c1bb26ba0d42facc77011db7)) - Mumulhl
- format code - ([f71d157](https://github.com/mumu-lhl/Ciyue/commit/f71d157a01a115c561dfc4d1b2074cc279f2c7fc)) - Mumulhl
- format code - ([acb84f5](https://github.com/mumu-lhl/Ciyue/commit/acb84f5b6ed01b685cb86b568d1a08befd33c0b2)) - Mumulhl
- format code - ([4624fa4](https://github.com/mumu-lhl/Ciyue/commit/4624fa49b4ad6bf0074b824229f98745dc4dfd35)) - Mumulhl

---
## [1.2.0](https://github.com/mumu-lhl/Ciyue/compare/v1.2.0-beta.1..v1.2.0) - 2025-02-01

### Bug Fixes

- fix update button in manage dictionaries page - ([e2d8570](https://github.com/mumu-lhl/Ciyue/commit/e2d85705615c63a103ee70f2898dd42c067c3f29)) - Mumulhl
- disable scroll on TabBarView in WebviewDisplay - ([6787fa1](https://github.com/mumu-lhl/Ciyue/commit/6787fa1ba343b92a919994b1f51ee84afd74df22)) - Mumulhl

### Features

- add sidebar icon toggle - ([20930e3](https://github.com/mumu-lhl/Ciyue/commit/20930e3ed838b7950e679e65dbebe6e6c87af499)) - Mumulhl
- implement dismissible history items - ([05d2d16](https://github.com/mumu-lhl/Ciyue/commit/05d2d16287f3b20845f399e92ce1a96c1d26ac3d)) - Mumulhl

### Miscellaneous Chores

- **(ci)** fix windows upload - ([5b3ecfb](https://github.com/mumu-lhl/Ciyue/commit/5b3ecfb8eafa616e764d13835142f0434e8af5f2)) - Mumulhl

### Refactoring

- change database directory on Desktop - ([a16b12b](https://github.com/mumu-lhl/Ciyue/commit/a16b12b9b4296835f5531ea9c818bd13c282d61c)) - Mumulhl

### Style

- format code - ([ba90cd2](https://github.com/mumu-lhl/Ciyue/commit/ba90cd2cd467671ae67e9fe3cc67e780709e78ba)) - Mumulhl
- format code - ([8930dae](https://github.com/mumu-lhl/Ciyue/commit/8930dae0466d9e580bbfcf77e275a5569b375242)) - Mumulhl
- format code - ([1b3b4cd](https://github.com/mumu-lhl/Ciyue/commit/1b3b4cdd60e7278a74860a3e9d04b77e4a75c9e3)) - Mumulhl

---
## [1.2.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.1.0..v1.2.0-beta.1) - 2025-01-31

### Bug Fixes

- Anti-Screenshots become ineffective every time Ciyue is reopened - ([b138ac1](https://github.com/mumu-lhl/Ciyue/commit/b138ac1d9726741579612bdfe92c566ca18be781)) - Mumulhl
- fix name - ([977e3e4](https://github.com/mumu-lhl/Ciyue/commit/977e3e480e9df5dc4a9b9114db3b7d5fea10cd79)) - Mumulhl

### Features

- **(localization)** update German localization strings and remove unused metadata - ([865cf93](https://github.com/mumu-lhl/Ciyue/commit/865cf93f64255914498d66e9c8abe48b2e158561)) - Mumulhl
- support windows - ([ba7a931](https://github.com/mumu-lhl/Ciyue/commit/ba7a93134081b985ab0076022504d337068c7f61)) - Mumulhl
- implement HTTP server for Windows and update webview handling - ([8ddae57](https://github.com/mumu-lhl/Ciyue/commit/8ddae57eecbc316bb4c1c1b7272324d787f9c5ac)) - Mumulhl
- update Flutter workflows for windows and remove deprecated PR workflow - ([b1b6526](https://github.com/mumu-lhl/Ciyue/commit/b1b6526eda37bfcf42f68cf084c75466b922cf3d)) - Mumulhl
- update flutter_tts dependency to use git source - ([f2aa173](https://github.com/mumu-lhl/Ciyue/commit/f2aa1735b5b29778f9d5f131202045814d760b42)) - Mumulhl
- add search bar location setting - ([a89da00](https://github.com/mumu-lhl/Ciyue/commit/a89da00602b9bf9f5c4b25eeab94e4d298d9ad60)) - Mumulhl

### Miscellaneous Chores

- **(ci)** upload windows zip - ([c466158](https://github.com/mumu-lhl/Ciyue/commit/c466158272070187f41fb0c9ef5f687d74a31888)) - Mumulhl
- **(ci)** add Windows build to release workflow - ([54bfba2](https://github.com/mumu-lhl/Ciyue/commit/54bfba26da5d118bbeac5ff9384e5642ec0d658e)) - Mumulhl
- **(ci)** include Ciyue.zip in release artifacts - ([95406fc](https://github.com/mumu-lhl/Ciyue/commit/95406fc826fa37aa1d3d58dfbbcf1949209d6f5e)) - Mumulhl
- **(ci)** fix release - ([a919852](https://github.com/mumu-lhl/Ciyue/commit/a9198528564fd8bcaed785ffd0c021f92f92feb6)) - Mumulhl
- **(ci)** add release permissions - ([cd9335d](https://github.com/mumu-lhl/Ciyue/commit/cd9335de0271730339275c45a9b42d5d1791f72a)) - Mumulhl
- **(ci)** update artifact paths in release workflow - ([f7e174f](https://github.com/mumu-lhl/Ciyue/commit/f7e174fbf5fb5da55c115927c74e2343151092ef)) - Mumulhl
- **(ci)** update artifact paths in release workflow - ([7dad755](https://github.com/mumu-lhl/Ciyue/commit/7dad755a80b0688dd78a5655ad173f137b8a647a)) - Mumulhl
- **(deps)** update - ([7b069cf](https://github.com/mumu-lhl/Ciyue/commit/7b069cfcf2fecf9d37e61b5eb6243595ab8041b4)) - Mumulhl

### Refactoring

- **(wordbook)** improve layout - ([63dc42f](https://github.com/mumu-lhl/Ciyue/commit/63dc42fd8627e868bc53482d1b3ce1eedbc3cd9c)) - Mumulhl
- remove useless code - ([189f5db](https://github.com/mumu-lhl/Ciyue/commit/189f5db1f7f2e03f59f7d3e8df769245576c65a8)) - Mumulhl
- update search bar location labels in multiple languages - ([3c4000a](https://github.com/mumu-lhl/Ciyue/commit/3c4000a2c5483ac2145929c81766d71e5077b2e9)) - Mumulhl

### Style

- format code - ([fe471af](https://github.com/mumu-lhl/Ciyue/commit/fe471af3f099a42ecc3cdc83388280fbad6dc1ed)) - Mumulhl
- format code - ([e954746](https://github.com/mumu-lhl/Ciyue/commit/e9547467125e279ec96d765419611496d511a56a)) - Mumulhl

---
## [1.1.0](https://github.com/mumu-lhl/Ciyue/compare/v1.1.0-beta.1..v1.1.0) - 2025-01-29

### Features

- **(translation)** added translation using Weblate (German) - ([e96d306](https://github.com/mumu-lhl/Ciyue/commit/e96d306ec5bd1eed4cd1e2e022c209cc0c42db3f)) - Jean-Luc Tibaux
- **(translation)** translated using Weblate (German) - ([abed181](https://github.com/mumu-lhl/Ciyue/commit/abed181f93c8dd7c7d1cf3ca6e87b6a065504c32)) - Jean-Luc Tibaux
- add secure screen feature - ([9e171e7](https://github.com/mumu-lhl/Ciyue/commit/9e171e7c55ba7a7229d68b2a434b3e9448969128)) - Mumulhl

### Miscellaneous Chores

- Add .aider* to gitignore - ([be77cd2](https://github.com/mumu-lhl/Ciyue/commit/be77cd2d9a8fa827d5ad611d6d2a249ddb797fd9)) - Mumulhl

---
## [1.1.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0..v1.1.0-beta.1) - 2025-01-26

### Features

- add sponsor - ([be735bf](https://github.com/mumu-lhl/Ciyue/commit/be735bf5da1b0fab744f88b1217222a647f8969c)) - Mumulhl
- add auto remove search word feature - ([dd28da4](https://github.com/mumu-lhl/Ciyue/commit/dd28da442ed8dfc79c02f588960ee0e3ba7d67d0)) - Mumulhl
- handle removal of missing dictionary files - ([f2b91b1](https://github.com/mumu-lhl/Ciyue/commit/f2b91b165ec176218e63cca37cce2fcf42542629)) - Mumulhl
- implement tag ordering - ([67f9234](https://github.com/mumu-lhl/Ciyue/commit/67f923465e08d5882d8f300ebc72cbf53396b5bc)) - Mumulhl
- migrate SharedPreferences to SharedPreferencesWithCache - ([99380b0](https://github.com/mumu-lhl/Ciyue/commit/99380b0eff0a74b376497e1a4799f342819d23bb)) - Mumulhl

### Miscellaneous Chores

- **(deps)** update - ([0550afe](https://github.com/mumu-lhl/Ciyue/commit/0550afe7036a54c268d02ad459e1207d844b3d86)) - Mumulhl

### Refactoring

- refactor TagListDialog - ([8fff5fc](https://github.com/mumu-lhl/Ciyue/commit/8fff5fc5561bd93085146e266e435dd98a88da89)) - Mumulhl

### Style

- format code - ([b0bdb28](https://github.com/mumu-lhl/Ciyue/commit/b0bdb2894bcc169e373710747e2fc6727bdbde49)) - Mumulhl

---
## [1.0.0](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0-beta.4..v1.0.0) - 2025-01-23

### Documentation

- update README.md and metadata - ([50316d1](https://github.com/mumu-lhl/Ciyue/commit/50316d1a70b1e99b50026ae7e0c87d453a6f7a11)) - Mumulhl

### Features

- add properties page - ([b53ecf8](https://github.com/mumu-lhl/Ciyue/commit/b53ecf8248e0e496c8b4759a685fa9235bc02e71)) - Mumulhl
- add title and total number of entries to localization files - ([f3debf9](https://github.com/mumu-lhl/Ciyue/commit/f3debf9173e4c890ac347292238042cd73aa22e9)) - Mumulhl

### Miscellaneous Chores

- update Flutter version to 3.27.3 in release workflow - ([0d25ccb](https://github.com/mumu-lhl/Ciyue/commit/0d25ccb42f62c658dea23063dcd54f2f768119fd)) - Mumulhl

### Refactoring

- remove unused codes - ([15ea1f7](https://github.com/mumu-lhl/Ciyue/commit/15ea1f72dbaf79681a976a979398c282487eb449)) - Mumulhl

### Style

- format code - ([ecc56ec](https://github.com/mumu-lhl/Ciyue/commit/ecc56ece703cffb4a52ca1331bbb5885db2ce35a)) - Mumulhl

---
## [1.0.0-beta.4](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0-beta.3..v1.0.0-beta.4) - 2025-01-23

### Bug Fixes

- auto export feature - ([6d583ee](https://github.com/mumu-lhl/Ciyue/commit/6d583ee4eb40c091afb900f33c744b2b6508055b)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump flutter_launcher_icons from 0.14.2 to 0.14.3 - ([f3e8d8f](https://github.com/mumu-lhl/Ciyue/commit/f3e8d8f3b0e9b76b383de49caa65b8358b50e1e2)) - dependabot[bot]

---
## [1.0.0-beta.3](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0-beta.2..v1.0.0-beta.3) - 2025-01-19

### Features

- add loading dialog when adding dictionaries - ([a5b2110](https://github.com/mumu-lhl/Ciyue/commit/a5b211065dfdd8e6c8c264ddacf5066e5a891264)) - Mumulhl

### Miscellaneous Chores

- **(ci)** update flutter version - ([946018b](https://github.com/mumu-lhl/Ciyue/commit/946018b69d6499357223153f492eb7069d76e6d3)) - Mumulhl
- bump copyright year - ([367a39b](https://github.com/mumu-lhl/Ciyue/commit/367a39ba29524605489bc2e5bd9563e9fba94213)) - Mumulhl

---
## [1.0.0-beta.2](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0-beta.1..v1.0.0-beta.2) - 2025-01-18

### Bug Fixes

- export workbook - ([2eeeb1b](https://github.com/mumu-lhl/Ciyue/commit/2eeeb1b48d8d3ecdc9655a038b21d42e2a4bd10c)) - Mumulhl
- import wordbook - ([5f0c0a7](https://github.com/mumu-lhl/Ciyue/commit/5f0c0a7e53e770b514cdc6fb786fc30ea6ea43f3)) - Mumulhl

### Features

- **(localization)** add default and manage groups translations - ([e4bdc7a](https://github.com/mumu-lhl/Ciyue/commit/e4bdc7a88d71292860df6a4b34abc165e90ea727)) - Mumulhl
- **(translation)** translated using Weblate (Persian) - ([805de30](https://github.com/mumu-lhl/Ciyue/commit/805de3023db7c10b304e3e3827c90bd7ff88bdce)) - Mo
- remove announcement - ([794f920](https://github.com/mumu-lhl/Ciyue/commit/794f920e7c5a8f397d748487fbcbd43fcc0dd1c8)) - Mumulhl

### Miscellaneous Chores

- **(build)** reduce apk size - ([20e1ba9](https://github.com/mumu-lhl/Ciyue/commit/20e1ba903101ee3609c68f02b113321a926a6a28)) - Mumulhl
- **(ci)** fix ci - ([e1bb757](https://github.com/mumu-lhl/Ciyue/commit/e1bb757749820ed3e525a3325520dda246e27129)) - Mumulhl
- **(ci)** fix apt install - ([7785644](https://github.com/mumu-lhl/Ciyue/commit/77856442f5394591beabfda25c664be3cf7b1d9a)) - Mumulhl
- **(ci)** install libsqlite3-dev - ([525ad29](https://github.com/mumu-lhl/Ciyue/commit/525ad29ef818b911a83d5d01b35a0f283e963933)) - Mumulhl
- **(deps)** bump go_router from 14.6.2 to 14.6.3 - ([6d4771c](https://github.com/mumu-lhl/Ciyue/commit/6d4771c99749eb7869519a792b380ab1a095bc01)) - dependabot[bot]
- **(deps)** update - ([3e921eb](https://github.com/mumu-lhl/Ciyue/commit/3e921eb1a2ac205f66b11ad31c49efa93b8a261d)) - Mumulhl
- remove external storage permission - ([7833b14](https://github.com/mumu-lhl/Ciyue/commit/7833b145901340d3a54f0963653cd5f2bcbfcf83)) - Mumulhl
- update AGP - ([2da10e0](https://github.com/mumu-lhl/Ciyue/commit/2da10e0815246eab88fedc6d404ca3cc6cd17d08)) - Mumulhl

### Style

- format code - ([9d8c1f8](https://github.com/mumu-lhl/Ciyue/commit/9d8c1f8a191c5e8aea82ebd525ab1c3ab34747f7)) - Mumulhl

---
## [1.0.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v0.16.0..v1.0.0-beta.1) - 2025-01-07

### Bug Fixes

- fix l10n - ([83ed02b](https://github.com/mumu-lhl/Ciyue/commit/83ed02b4c29745e94c15b2ff866dc5c4de554691)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump drift from 2.23.0 to 2.23.1 - ([128de43](https://github.com/mumu-lhl/Ciyue/commit/128de4353351e6cff306e07e1661996699f7c199)) - dependabot[bot]
- **(deps)** bump shared_preferences from 2.3.4 to 2.3.5 - ([1c5604a](https://github.com/mumu-lhl/Ciyue/commit/1c5604ae76f4a0cc4951a5632cfed72ff1536d08)) - dependabot[bot]
- **(deps)** bump drift_dev from 2.23.0 to 2.23.1 - ([a4043a9](https://github.com/mumu-lhl/Ciyue/commit/a4043a9001932f2ab4cff4b5baa532d7ded0591c)) - dependabot[bot]

---
## [0.16.0](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0-alpha.3..v0.16.0) - 2025-01-01

### Features

- **(language)** add Persian in language selector - ([37589be](https://github.com/mumu-lhl/Ciyue/commit/37589bec4a18254761efdec2bcb09e83184b5b01)) - Mumulhl
- **(translation)** translated using Weblate (Sardinian) - ([29aea63](https://github.com/mumu-lhl/Ciyue/commit/29aea63545527c1866a3dbf0580bade5421b43e9)) - Ajeje Brazorf
- **(translation)** added translation using Weblate (Persian) - ([f065cbb](https://github.com/mumu-lhl/Ciyue/commit/f065cbbe934b19e1c1ade885c1545656297f5c09)) - Mo
- **(translation)** translated using Weblate (Persian) - ([a1be096](https://github.com/mumu-lhl/Ciyue/commit/a1be09631bf4a90d2581e52b2b25a4d85bb56d2c)) - Mo
- **(translation)** translated using Weblate (Russian) - ([6e024a2](https://github.com/mumu-lhl/Ciyue/commit/6e024a294a7d64f273981a3b168b85005f88da3e)) - Xapitonov
- remove external storage permission - ([ccdfec9](https://github.com/mumu-lhl/Ciyue/commit/ccdfec9cf6b727a634e955059ff1ec35c75d430c)) - Mumulhl
- add update button - ([7da3688](https://github.com/mumu-lhl/Ciyue/commit/7da36886c783db60bf5f4c8e6456bd4fd3f75e6e)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump drift_dev from 2.22.1 to 2.23.0 ([#97](https://github.com/mumu-lhl/Ciyue/issues/97)) - ([668a5d5](https://github.com/mumu-lhl/Ciyue/commit/668a5d513978622ba0ed8e3266ff93003ba83722)) - dependabot[bot]
- **(deps)** bump flutter_tts from 4.2.0 to 4.2.1 ([#98](https://github.com/mumu-lhl/Ciyue/issues/98)) - ([fc6b4e9](https://github.com/mumu-lhl/Ciyue/commit/fc6b4e97ced9d2cfc04b69c1341aa081fa514655)) - dependabot[bot]
- **(deps)** bump drift_flutter from 0.2.3 to 0.2.4 ([#100](https://github.com/mumu-lhl/Ciyue/issues/100)) - ([330a4b9](https://github.com/mumu-lhl/Ciyue/commit/330a4b92aa40ff1a338f269d29d36c6e0ebf880c)) - dependabot[bot]

### Style

- format code - ([93b2adf](https://github.com/mumu-lhl/Ciyue/commit/93b2adf0a0ab640dad82c16e1887e34882293f27)) - Mumulhl
- format code - ([ef003f0](https://github.com/mumu-lhl/Ciyue/commit/ef003f0b421a30161e880552cdc9c3b780b19299)) - Mumulhl

---
## [1.0.0-alpha.3](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0-alpha.2..v1.0.0-alpha.3) - 2025-01-06

### Bug Fixes

- fix sort dictionaries - ([1d9be71](https://github.com/mumu-lhl/Ciyue/commit/1d9be71af19bf089677c6d061fc4e35466e0610f)) - Mumulhl
- fix sort dictionaries - ([fa1d2fa](https://github.com/mumu-lhl/Ciyue/commit/fa1d2fa5719cf817b9c0623429d2d9e8ea2f903b)) - Mumulhl
- fix drawer - ([35a55f5](https://github.com/mumu-lhl/Ciyue/commit/35a55f54325872a5c738a7eb531e568b68f708de)) - Mumulhl

### Features

- group dictionaries - ([9944dd6](https://github.com/mumu-lhl/Ciyue/commit/9944dd6e45ec2fe25f69251453029d6d560c0e76)) - Mumulhl
- implement group bugly - ([7589015](https://github.com/mumu-lhl/Ciyue/commit/7589015c6a86848450f1b785b79fec4b4cd5726f)) - Mumulhl
- implement group fully - ([2ad1e42](https://github.com/mumu-lhl/Ciyue/commit/2ad1e422a7ecccd8bff47f5f1caa9390f4757358)) - Mumulhl
- finish group dictionaries - ([9502310](https://github.com/mumu-lhl/Ciyue/commit/9502310f48f0b50ac1c21e67a7a980426f323e28)) - Mumulhl

### Style

- format code - ([1bc13bd](https://github.com/mumu-lhl/Ciyue/commit/1bc13bd918b2360bc2ce22d776cf92fa96f993ab)) - Mumulhl

---
## [1.0.0-alpha.2](https://github.com/mumu-lhl/Ciyue/compare/v1.0.0-alpha.1..v1.0.0-alpha.2) - 2024-12-31

### Features

- look up history - ([fdaa3a8](https://github.com/mumu-lhl/Ciyue/commit/fdaa3a85c32f5478b5cb4a11faf8b3a5d961bb05)) - Mumulhl
- look up history ([#101](https://github.com/mumu-lhl/Ciyue/issues/101)) - ([4affaec](https://github.com/mumu-lhl/Ciyue/commit/4affaecdcd03f035206bd29e5fa30a98f9a0abbd)) - Mumulhl

### Refactoring

- **(database)** refactor database - ([e656ce7](https://github.com/mumu-lhl/Ciyue/commit/e656ce7dcf36cfc36b1ff1c7c5b2d14ac21cf357)) - Mumulhl

---
## [1.0.0-alpha.1](https://github.com/mumu-lhl/Ciyue/compare/v0.15.1..v1.0.0-alpha.1) - 2024-12-29

### Bug Fixes

- fix unselect dictionary - ([f1a16ed](https://github.com/mumu-lhl/Ciyue/commit/f1a16ed86917f25de5a486a27b4e12ba0d7c4e39)) - Mumulhl
- fix wordbook - ([3fdd522](https://github.com/mumu-lhl/Ciyue/commit/3fdd52246ff0d41e07425cba5081c16c3c2a53fc)) - Mumulhl

### Features

- support mutiple dictionaries bugly - ([4577245](https://github.com/mumu-lhl/Ciyue/commit/45772459a9d2d3a5038d5f688402c5ba77d237a9)) - Mumulhl
- support multiple dictionaries in searching and displaying - ([b99470c](https://github.com/mumu-lhl/Ciyue/commit/b99470cd61c4f6527065cd82cdf75012a671fbca)) - Mumulhl
- support settings for mutiple dictionaries - ([a12633d](https://github.com/mumu-lhl/Ciyue/commit/a12633dceb16faed090f1e10d4cf2e5b9980568b)) - Mumulhl

### Refactoring

- refactor database - ([766f2fe](https://github.com/mumu-lhl/Ciyue/commit/766f2fef3a6e2722a9e5b82820503e35fe1a07c2)) - Mumulhl

### Style

- format - ([b10eace](https://github.com/mumu-lhl/Ciyue/commit/b10eaceabdb3479f2350fffc03f3be812b4ca3d5)) - Mumulhl

---
## [0.15.1](https://github.com/mumu-lhl/Ciyue/compare/v0.15.0..v0.15.1) - 2024-12-22

### Miscellaneous Chores

- **(ci)** update flutter version - ([b93d6a3](https://github.com/mumu-lhl/Ciyue/commit/b93d6a3a49c128b7d1986a78da6979a8d1318450)) - Mumulhl
- **(deps)** bump build_runner from 2.4.13 to 2.4.14 ([#91](https://github.com/mumu-lhl/Ciyue/issues/91)) - ([45e1290](https://github.com/mumu-lhl/Ciyue/commit/45e1290f125e5d3c26efa6b4e79e5f2375011b1c)) - dependabot[bot]
- **(deps)** bump shared_preferences from 2.3.3 to 2.3.4 ([#92](https://github.com/mumu-lhl/Ciyue/issues/92)) - ([c79bb61](https://github.com/mumu-lhl/Ciyue/commit/c79bb618af8b1dae175e43e37667cab753956aad)) - dependabot[bot]
- **(deps)** bump drift_flutter from 0.2.2 to 0.2.3 ([#93](https://github.com/mumu-lhl/Ciyue/issues/93)) - ([59c8ca5](https://github.com/mumu-lhl/Ciyue/commit/59c8ca5f966eb94ebe017a5c2ae00517fd56fe6d)) - dependabot[bot]

### Refactoring

- ignore space in the end in the search bar - ([03b8966](https://github.com/mumu-lhl/Ciyue/commit/03b896656e14af0efb1b072bf8473cc656fc3364)) - Mumulhl
- refactor manage dictionaries code - ([b812f7a](https://github.com/mumu-lhl/Ciyue/commit/b812f7af8a342a5aa134331c51f123a22fc46568)) - Mumulhl

---
## [0.15.0](https://github.com/mumu-lhl/Ciyue/compare/v0.14.0..v0.15.0) - 2024-12-15

### Features

- **(translation)** added translation using Weblate (Tamil) - ([ea6786b](https://github.com/mumu-lhl/Ciyue/commit/ea6786b820f1486f45804bff61c82aca98d3227c)) - தமிழ்நேரம்
- **(translation)** translated using Weblate (Tamil) - ([f2043ad](https://github.com/mumu-lhl/Ciyue/commit/f2043ad666ad7c78150ca2137d09d31c6b165fb3)) - தமிழ்நேரம்
- **(translation)** add Tamil language - ([f00ebce](https://github.com/mumu-lhl/Ciyue/commit/f00ebce056cde51b259f4ab804fd7869bbec10e6)) - Mumulhl

### Miscellaneous Chores

- **(ci)** update flutter version - ([a844d36](https://github.com/mumu-lhl/Ciyue/commit/a844d36e610bd68c181c55c87d05e8fb0893168c)) - Mumulhl
- **(ci)** update flutter version - ([c8fc5f6](https://github.com/mumu-lhl/Ciyue/commit/c8fc5f6619f1a877058331d95b1f2b3bd852eb78)) - Mumulhl
- **(deps)** bump test from 1.25.7 to 1.25.8 ([#86](https://github.com/mumu-lhl/Ciyue/issues/86)) - ([a9a644c](https://github.com/mumu-lhl/Ciyue/commit/a9a644c222d348e0f58ecc6aa632e4dacf4129f2)) - dependabot[bot]
- **(deps)** bump device_info_plus from 11.1.1 to 11.2.0 ([#85](https://github.com/mumu-lhl/Ciyue/issues/85)) - ([c2b9a5c](https://github.com/mumu-lhl/Ciyue/commit/c2b9a5c3d4a17089d8517c5d39610b949ba9736f)) - dependabot[bot]
- **(deps)** bump package_info_plus from 8.1.1 to 8.1.2 ([#84](https://github.com/mumu-lhl/Ciyue/issues/84)) - ([1691ad2](https://github.com/mumu-lhl/Ciyue/commit/1691ad21dd37abcc862259c3ef4484fd35d27cbf)) - dependabot[bot]

---
## [0.14.0](https://github.com/mumu-lhl/Ciyue/compare/v0.13.1..v0.14.0) - 2024-12-08

### Features

- notice users the announcement of update - ([b235997](https://github.com/mumu-lhl/Ciyue/commit/b235997526f9c69f8b01c5c6b307119bc47fbc7f)) - Mumulhl

### Miscellaneous Chores

- **(ci)** modify the cron of the thread locker - ([c7858c7](https://github.com/mumu-lhl/Ciyue/commit/c7858c7f7decb12ae9ebb54e32f681a7497b4f8a)) - Mumulhl
- **(deps)** bump drift from 2.21.0 to 2.22.1 ([#70](https://github.com/mumu-lhl/Ciyue/issues/70)) - ([6382f9d](https://github.com/mumu-lhl/Ciyue/commit/6382f9db68a215c8b3082900fa35e0c80ab65f6b)) - dependabot[bot]
- **(deps)** bump drift_flutter from 0.2.1 to 0.2.2 ([#71](https://github.com/mumu-lhl/Ciyue/issues/71)) - ([7d93618](https://github.com/mumu-lhl/Ciyue/commit/7d93618c95721d296eea57898b57a9309b0a2c3b)) - dependabot[bot]
- **(deps)** bump flutter_launcher_icons from 0.14.1 to 0.14.2 ([#75](https://github.com/mumu-lhl/Ciyue/issues/75)) - ([34c9484](https://github.com/mumu-lhl/Ciyue/commit/34c9484bd1bf73495e0b5526fee8d11e0d0fad3b)) - dependabot[bot]
- **(deps)** bump go_router from 14.6.1 to 14.6.2 ([#76](https://github.com/mumu-lhl/Ciyue/issues/76)) - ([8956e09](https://github.com/mumu-lhl/Ciyue/commit/8956e0962ec1973b8794c878a85d2243bc9e2b3c)) - dependabot[bot]
- **(deps)** bump drift_dev from 2.22.0 to 2.22.1 ([#77](https://github.com/mumu-lhl/Ciyue/issues/77)) - ([f892345](https://github.com/mumu-lhl/Ciyue/commit/f892345c5703508c79cc7a1f7d38aea958d99a5a)) - dependabot[bot]
- **(deps)** update - ([da53695](https://github.com/mumu-lhl/Ciyue/commit/da53695c2fa06c269456a4b13bf95d08f0779fc7)) - Mumulhl

### Refactoring

- `Dict` class - ([90b0173](https://github.com/mumu-lhl/Ciyue/commit/90b0173ee8a01480961ae332e0fc9fc7c4ac5bb8)) - Mumulhl

### Tests

- fix import - ([e89418d](https://github.com/mumu-lhl/Ciyue/commit/e89418d988920cc395752ae3532f535ec91ba4d9)) - Mumulhl
- fix import package - ([cc4cb0c](https://github.com/mumu-lhl/Ciyue/commit/cc4cb0c47ed71fb70f4537ee04bb8ad70fdf7059)) - Mumulhl
- fix migration import - ([0ab306e](https://github.com/mumu-lhl/Ciyue/commit/0ab306e2a9f8b9b193df4cbfed08a51c422148b0)) - Mumulhl

---
## [0.13.1](https://github.com/mumu-lhl/Ciyue/compare/v0.13.0..v0.13.1) - 2024-12-01

### Miscellaneous Chores

- **(deps)** bump go_router from 14.6.0 to 14.6.1 ([#63](https://github.com/mumu-lhl/Ciyue/issues/63)) - ([c420a74](https://github.com/mumu-lhl/Ciyue/commit/c420a74d15f5d8a7288101781d556aca7f915a1a)) - dependabot[bot]
- **(deps)** remove useless dependent - ([63c8f8c](https://github.com/mumu-lhl/Ciyue/commit/63c8f8cae9c54abf129ebf2ca18355cda419cbf5)) - Mumulhl
- **(translation)** translated using Weblate (Sardinian) ([#62](https://github.com/mumu-lhl/Ciyue/issues/62)) - ([3afb036](https://github.com/mumu-lhl/Ciyue/commit/3afb03638a0ec872e3f0b008500136b919fa665d)) - Weblate (bot)
- configuring automatically generated release notes ([#66](https://github.com/mumu-lhl/Ciyue/issues/66)) - ([316fe4a](https://github.com/mumu-lhl/Ciyue/commit/316fe4a6ec3c165ee778aa7419bb0ea5c026ff49)) - Mumulhl
- disable generating release changelog by git-cliff - ([f33d701](https://github.com/mumu-lhl/Ciyue/commit/f33d7012e8119a01e689d9789463bf0d500c28b7)) - Mumulhl

### Refactoring

- display no result when search word not in the dict ([#65](https://github.com/mumu-lhl/Ciyue/issues/65)) - ([c49c224](https://github.com/mumu-lhl/Ciyue/commit/c49c22432c07de739413cb2a0443f3172102f187)) - Mumulhl
- refactor path - ([c215604](https://github.com/mumu-lhl/Ciyue/commit/c2156043dfd81c58aee4fd75467cb5c5972338a8)) - Mumulhl
- refactor settings - ([ba08d6d](https://github.com/mumu-lhl/Ciyue/commit/ba08d6d5cce1bc199975020c0b02c6350ccc7f3d)) - Mumulhl
- webview display - ([5adffbe](https://github.com/mumu-lhl/Ciyue/commit/5adffbeb18820925a8d4115aa7d9076dcee6fd76)) - Mumulhl

---
## [0.13.0](https://github.com/mumu-lhl/Ciyue/compare/v0.12.0..v0.13.0) - 2024-11-24

### Features

- support share text menu ([#60](https://github.com/mumu-lhl/Ciyue/issues/60)) - ([a61f863](https://github.com/mumu-lhl/Ciyue/commit/a61f86345b31ed3c387cb84b2fcd4b9787102813)) - Mumulhl

### Miscellaneous Chores

- create FUNDING.yml - ([bb23ca1](https://github.com/mumu-lhl/Ciyue/commit/bb23ca1a386420739dc30a07c5778151c498e093)) - Mumulhl

---
## [0.12.0](https://github.com/mumu-lhl/Ciyue/compare/v0.11.2..v0.12.0) - 2024-11-16

### Features

- support context menu ([#55](https://github.com/mumu-lhl/Ciyue/issues/55)) - ([043c8a3](https://github.com/mumu-lhl/Ciyue/commit/043c8a3dcc299f7ee22044b38a1002279f2f2c78)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump shared_preferences from 2.3.2 to 2.3.3 ([#47](https://github.com/mumu-lhl/Ciyue/issues/47)) - ([4a43577](https://github.com/mumu-lhl/Ciyue/commit/4a43577cd3506b07921dc2ddc1865aa4091df398)) - dependabot[bot]
- **(deps)** bump package_info_plus from 8.1.0 to 8.1.1 ([#48](https://github.com/mumu-lhl/Ciyue/issues/48)) - ([9ed4eae](https://github.com/mumu-lhl/Ciyue/commit/9ed4eae9223d797072591af74248540da94f3f2c)) - dependabot[bot]
- **(deps)** bump flutter_tts from 4.0.2 to 4.1.0 ([#50](https://github.com/mumu-lhl/Ciyue/issues/50)) - ([9820df4](https://github.com/mumu-lhl/Ciyue/commit/9820df4bebb62062624b152b8b16a0deb53b96ee)) - dependabot[bot]
- **(deps)** bump go_router from 14.3.0 to 14.6.0 ([#53](https://github.com/mumu-lhl/Ciyue/issues/53)) - ([c4dac51](https://github.com/mumu-lhl/Ciyue/commit/c4dac51bbdad39167233573d352c70d463079fbd)) - dependabot[bot]
- **(deps)** bump device_info_plus from 11.1.0 to 11.1.1 ([#51](https://github.com/mumu-lhl/Ciyue/issues/51)) - ([a1935be](https://github.com/mumu-lhl/Ciyue/commit/a1935be5dff7c681796724761a069b674ecfadfa)) - dependabot[bot]
- **(deps)** bump flutter_tts from 4.1.0 to 4.2.0 ([#54](https://github.com/mumu-lhl/Ciyue/issues/54)) - ([58d95d2](https://github.com/mumu-lhl/Ciyue/commit/58d95d2e307076cb473a7ea83dc0c6d508610ff8)) - dependabot[bot]
- **(deps)** update - ([c252820](https://github.com/mumu-lhl/Ciyue/commit/c2528202f09ffc67a74c09d5a82340dd867ad2ef)) - Mumulhl

### Refactoring

- order wordbook ([#56](https://github.com/mumu-lhl/Ciyue/issues/56)) - ([d9e6cf6](https://github.com/mumu-lhl/Ciyue/commit/d9e6cf672ef3ab0ff43dfa7d503807682c38e0fb)) - Mumulhl
- reduce code - ([047dd2c](https://github.com/mumu-lhl/Ciyue/commit/047dd2c8ae4656919a52db0d92f414110116a7cd)) - Mumulhl

### Style

- new icon and remove splash screen ([#57](https://github.com/mumu-lhl/Ciyue/issues/57)) - ([28302b3](https://github.com/mumu-lhl/Ciyue/commit/28302b386628601f5dda57323f82ba9642569537)) - Mumulhl

---
## [0.11.2](https://github.com/mumu-lhl/Ciyue/compare/v0.11.1..v0.11.2) - 2024-11-10

### Bug Fixes

- **(ui)** refresh instantly after adding tag - ([e56e072](https://github.com/mumu-lhl/Ciyue/commit/e56e0722c72e4bdd4f5e97d405856e52c91d2b1a)) - Mumulhl

### Refactoring

- refactor dialog - ([a7f3aff](https://github.com/mumu-lhl/Ciyue/commit/a7f3aff19a6cdc140cc5ea23199e2fb03db6b370)) - Mumulhl

---
## [0.11.1](https://github.com/mumu-lhl/Ciyue/compare/v0.11.0..v0.11.1) - 2024-11-09

### Bug Fixes

- **(build)** remove `DependencyInfoBlock` - ([b191834](https://github.com/mumu-lhl/Ciyue/commit/b191834e33466de1c68e0f7da8ff3046b01918ed)) - Mumulhl

### Miscellaneous Chores

- **(translation)** translations update from Hosted Weblate ([#44](https://github.com/mumu-lhl/Ciyue/issues/44)) - ([7b7eff9](https://github.com/mumu-lhl/Ciyue/commit/7b7eff98ffe413aebf97ce697e13f244848ebbb4)) - Weblate (bot)

---
## [0.11.0](https://github.com/mumu-lhl/Ciyue/compare/v0.10.1..v0.11.0) - 2024-11-01

### Features

- **(language)** support Русский - ([239ac59](https://github.com/mumu-lhl/Ciyue/commit/239ac597097d6bc944a720abbc396a760852f149)) - Mumulhl
- tag word in wordbook ([#42](https://github.com/mumu-lhl/Ciyue/issues/42)) - ([d9f7242](https://github.com/mumu-lhl/Ciyue/commit/d9f72420c88e9c8b2c4d7ca41fa05b5936b44d4e)) - Mumulhl

### Miscellaneous Chores

- **(ci)** add test - ([cfba288](https://github.com/mumu-lhl/Ciyue/commit/cfba288782a80b9b1a06bad36c67633f2235039e)) - Mumulhl
- **(deps)** bump drift_dev from 2.21.1 to 2.21.2 ([#39](https://github.com/mumu-lhl/Ciyue/issues/39)) - ([4e0d327](https://github.com/mumu-lhl/Ciyue/commit/4e0d3279fb242f334fd7cdac7f6076776730144d)) - dependabot[bot]
- **(deps)** update - ([54b9bd4](https://github.com/mumu-lhl/Ciyue/commit/54b9bd4f20347f731f7195b76d8524bc2bad797a)) - Mumulhl
- **(deps)** update - ([038b813](https://github.com/mumu-lhl/Ciyue/commit/038b813c27958477501746ff06c51a41f79a66b9)) - Mumulhl

### Refactoring

- **(database)** refactor migration - ([90ea7a3](https://github.com/mumu-lhl/Ciyue/commit/90ea7a336cdbdfb64ce5bb11c8c9a1409034b594)) - Mumulhl

---
## [0.10.1](https://github.com/mumu-lhl/Ciyue/compare/v0.10.0..v0.10.1) - 2024-10-27

### Miscellaneous Chores

- **(deps)** bump flutter_native_splash from 2.4.1 to 2.4.2 ([#36](https://github.com/mumu-lhl/Ciyue/issues/36)) - ([3c19293](https://github.com/mumu-lhl/Ciyue/commit/3c19293089bb39e1aa9e45e0141d3d37bd07fba9)) - dependabot[bot]
- **(deps)** update - ([6940076](https://github.com/mumu-lhl/Ciyue/commit/6940076786178f77bc33757198adda46d01079a8)) - Mumulhl
- **(deps)** update - ([e358127](https://github.com/mumu-lhl/Ciyue/commit/e358127dce1bf78a0d7d180613013e021ec3b6d4)) - Mumulhl
- modify abi codes - ([b959e62](https://github.com/mumu-lhl/Ciyue/commit/b959e62c28f279eba5e8b251efde09b50a062078)) - Mumulhl

---
## [0.10.0](https://github.com/mumu-lhl/Ciyue/compare/v0.9.0..v0.10.0) - 2024-10-20

### Bug Fixes

- fix adding dictionary - ([c553fda](https://github.com/mumu-lhl/Ciyue/commit/c553fdad4433b83dab2decc98c3732291730ae4a)) - Mumulhl
- fix no search result after switching bottom destination - ([61cbbde](https://github.com/mumu-lhl/Ciyue/commit/61cbbde3a0e4face79078dbc7b0fc083847d762a)) - Mumulhl

### Features

- scan in mutiple paths - ([b1fe716](https://github.com/mumu-lhl/Ciyue/commit/b1fe7163c73687d6645ff67624abd0911cec0b21)) - Mumulhl
- auto export - ([a53ee9b](https://github.com/mumu-lhl/Ciyue/commit/a53ee9b844c55e9e3f1575ace2cda425de383ab3)) - Mumulhl

### Miscellaneous Chores

- **(ci)** disable build appbundle for release - ([92279a2](https://github.com/mumu-lhl/Ciyue/commit/92279a2eb00bb44a9c5cb8139475e41c26b64b5e)) - Mumulhl
- **(deps)** update - ([2ebc6ba](https://github.com/mumu-lhl/Ciyue/commit/2ebc6ba7f58333400f74f034c7471dd4682cc835)) - Mumulhl
- **(deps)** bump mime from 1.0.6 to 2.0.0 ([#31](https://github.com/mumu-lhl/Ciyue/issues/31)) - ([93d53a3](https://github.com/mumu-lhl/Ciyue/commit/93d53a30c9e943436f65fcc69ef1a921e3c8d85b)) - dependabot[bot]
- **(deps)** bump go_router from 14.2.9 to 14.3.0 ([#30](https://github.com/mumu-lhl/Ciyue/issues/30)) - ([0f99fc2](https://github.com/mumu-lhl/Ciyue/commit/0f99fc2602b124056d50f78d579c222309b70d8a)) - dependabot[bot]
- **(deps)** update - ([08ba2fc](https://github.com/mumu-lhl/Ciyue/commit/08ba2fce4ea88076cddd50134cec4c588fa9cc24)) - Mumulhl
- **(deps)** update - ([c2e92d8](https://github.com/mumu-lhl/Ciyue/commit/c2e92d8fa5da477d2ac469eef65fe43949b5f585)) - Mumulhl
- regenerate g.dart files - ([ceb8e5f](https://github.com/mumu-lhl/Ciyue/commit/ceb8e5fd9c75904e30e188b9af241b19084ad17f)) - Mumulhl

### Refactoring

- refactor code - ([b9a413e](https://github.com/mumu-lhl/Ciyue/commit/b9a413ef5f75b972e569b74ab39200320399747b)) - Mumulhl
- display empty in workbook screen when there is no dictionary - ([8d69ae8](https://github.com/mumu-lhl/Ciyue/commit/8d69ae862432f1bf197539492f96a7c2d9e6bc47)) - Mumulhl

### Style

- fix typo - ([40ce9b5](https://github.com/mumu-lhl/Ciyue/commit/40ce9b5f69f747324d14cd151fe8216f7bb34c9e)) - Mumulhl
- finish l10n - ([65c9fd0](https://github.com/mumu-lhl/Ciyue/commit/65c9fd0e33612eeb7c446a275ec30a7a2bb93d18)) - Mumulhl

---
## [0.9.0](https://github.com/mumu-lhl/Ciyue/compare/v0.8.3..v0.9.0) - 2024-10-03

### Bug Fixes

- fix read resource if resource is not in mdd - ([99b8ef5](https://github.com/mumu-lhl/Ciyue/commit/99b8ef5f1e99235fff125848192ce3f6a3993bba)) - Mumulhl
- fix entry url for encoded url - ([c9f7fda](https://github.com/mumu-lhl/Ciyue/commit/c9f7fda30b080b5b3c0ccde5f1702b2f277d8153)) - Mumulhl
- fix description display - ([f2e9e66](https://github.com/mumu-lhl/Ciyue/commit/f2e9e669979264eca5ebe73bdf1608879a7fd8af)) - Mumulhl

### Documentation

- **(readme)** add get it on obtainium - ([3b8acd8](https://github.com/mumu-lhl/Ciyue/commit/3b8acd8b61e8b0f8dc2e2ea7bd655a2b8847f590)) - Mumulhl
- **(readme)** update img alt - ([2e8c781](https://github.com/mumu-lhl/Ciyue/commit/2e8c781a5f52b095045580273c6f77deb4d9c768)) - Mumulhl

### Features

- add export and import to wordbook ([#25](https://github.com/mumu-lhl/Ciyue/issues/25)) - ([47fca75](https://github.com/mumu-lhl/Ciyue/commit/47fca75635dcb93ed0c9ed0ab680467ba8646fed)) - Mumulhl
- add viewing description to manage dictionaries - ([bf74358](https://github.com/mumu-lhl/Ciyue/commit/bf74358f716cb6b40d5aa5e870a5cb1a30178ca9)) - Mumulhl
- support scan dictionaries under a path - ([0ac77a2](https://github.com/mumu-lhl/Ciyue/commit/0ac77a2e94660834ad815adac6250727fc575e72)) - Mumulhl
- new icon and support adaptive icon ([#27](https://github.com/mumu-lhl/Ciyue/issues/27)) - ([be0211a](https://github.com/mumu-lhl/Ciyue/commit/be0211a16e586a7ab858317044add643d9f7a656)) - Mumulhl
- support custom font ([#28](https://github.com/mumu-lhl/Ciyue/issues/28)) - ([36eeefc](https://github.com/mumu-lhl/Ciyue/commit/36eeefcc608a2171784b8fcb77b2df057329660c)) - Mumulhl
- show empty when there is nothing in page - ([e3fee9d](https://github.com/mumu-lhl/Ciyue/commit/e3fee9dbfc55ead7dcff272a1c6317d43b410d18)) - Mumulhl

### Miscellaneous Chores

- **(ci)** update flutter version - ([3ce1bd3](https://github.com/mumu-lhl/Ciyue/commit/3ce1bd311b952dfefab80fbdc3d40e01bcd48e58)) - Mumulhl
- **(ci)** fix pr build - ([e3558b2](https://github.com/mumu-lhl/Ciyue/commit/e3558b21477b30fbd5b2f7a92c8faba8e3e62020)) - Mumulhl
- **(ci)** remove useless code - ([4a5a1d6](https://github.com/mumu-lhl/Ciyue/commit/4a5a1d65073cf2ad00a1e27cf33d8148d8d0b81b)) - Mumulhl
- **(ci)** update flutter version - ([3315034](https://github.com/mumu-lhl/Ciyue/commit/331503432d112f5c86ca8930ac5045bf11a6b866)) - Mumulhl
- **(ci)** update java version - ([ab09a2b](https://github.com/mumu-lhl/Ciyue/commit/ab09a2bf192d3d18ca2f666fcc7a5405d7291dcc)) - Mumulhl
- **(deps)** bump flutter_inappwebview from 6.0.0 to 6.1.0+1 ([#20](https://github.com/mumu-lhl/Ciyue/issues/20)) - ([5858af4](https://github.com/mumu-lhl/Ciyue/commit/5858af41801ff55c09bdbc6c00f816aa922e2688)) - dependabot[bot]
- **(deps)** bump flutter_launcher_icons from 0.13.1 to 0.14.0 ([#19](https://github.com/mumu-lhl/Ciyue/issues/19)) - ([b92dc5c](https://github.com/mumu-lhl/Ciyue/commit/b92dc5c6200daabe46b433539d0a66fc1776cae1)) - dependabot[bot]
- **(deps)** bump flutter_launcher_icons from 0.14.0 to 0.14.1 ([#21](https://github.com/mumu-lhl/Ciyue/issues/21)) - ([d3c647f](https://github.com/mumu-lhl/Ciyue/commit/d3c647fe2f379763748957cb566c920bfb063e47)) - dependabot[bot]
- **(deps)** update - ([85ad1ea](https://github.com/mumu-lhl/Ciyue/commit/85ad1ea59069bd5f94a4f391df46fc2e4167d8de)) - Mumulhl
- **(deps)** bump flutter_lints from 4.0.0 to 5.0.0 ([#23](https://github.com/mumu-lhl/Ciyue/issues/23)) - ([0dc525f](https://github.com/mumu-lhl/Ciyue/commit/0dc525ff629722e1bc10745893caba6693533b32)) - dependabot[bot]
- **(deps)** update - ([10f3488](https://github.com/mumu-lhl/Ciyue/commit/10f34888a1a0465d88df8e0870b18941ff6b6e78)) - Mumulhl
- **(deps)** update dict_reader - ([810e74e](https://github.com/mumu-lhl/Ciyue/commit/810e74e11ea2b94c95f47f56332acad753a857c3)) - Mumulhl
- **(deps)** update - ([e6fe39a](https://github.com/mumu-lhl/Ciyue/commit/e6fe39aaa9949a2dcd8d627586347f3c115daeb2)) - Mumulhl
- **(deps)** update - ([6d13550](https://github.com/mumu-lhl/Ciyue/commit/6d1355000167dab00db835d45aa3e21c2304d354)) - Mumulhl
- **(deps)** update flutter_inappwebview_android - ([63375d3](https://github.com/mumu-lhl/Ciyue/commit/63375d3e7f08934894ebfd99f602eecb9c4c3ad5)) - Mumulhl
- **(gradle)** update java version - ([ea16806](https://github.com/mumu-lhl/Ciyue/commit/ea16806cef28e11d42324df0323bc13ac87bf16a)) - Mumulhl
- **(metadata)** update screenshots - ([a3912a4](https://github.com/mumu-lhl/Ciyue/commit/a3912a49560ccbe0992f4f385a90725429c06d91)) - Mumulhl
- return null for request of favicon.ico - ([7cbbb51](https://github.com/mumu-lhl/Ciyue/commit/7cbbb51ef93d9f90a1c67ec11a809f21855732a6)) - Mumulhl

### Performance

- improve performance when changing dictionaries - ([0378733](https://github.com/mumu-lhl/Ciyue/commit/0378733b4900b2e6920d6d3b5c21469ad0cb1dbf)) - Mumulhl

### Refactoring

- **(l10n)** finish l10n - ([ab4bded](https://github.com/mumu-lhl/Ciyue/commit/ab4bded2b4568904ce92ba5e3d109630bbf2fbef)) - Mumulhl
- add system to language selector - ([eb785cd](https://github.com/mumu-lhl/Ciyue/commit/eb785cd137b99df72a653fccac5936742ca0f5a3)) - Mumulhl
- refactor description feature - ([3ec5135](https://github.com/mumu-lhl/Ciyue/commit/3ec51357d4c66b9a656e0281d4ca60600c18e61b)) - Mumulhl

### Revert

- docs(readme): add get it on obtainium - ([3f6539f](https://github.com/mumu-lhl/Ciyue/commit/3f6539f22441c4641cc4ab1fa927b12fe20efe1f)) - Mumulhl

### Style

- **(comment)** fix typo - ([330ef28](https://github.com/mumu-lhl/Ciyue/commit/330ef28f4651dba8ef0e8bb46ec0cfab01a20185)) - Mumulhl
- rename class name - ([b30817d](https://github.com/mumu-lhl/Ciyue/commit/b30817d25e1499d37f934c322c94b434d0b9376e)) - Mumulhl

---
## [0.8.3](https://github.com/mumu-lhl/Ciyue/compare/v0.8.2..v0.8.3) - 2024-09-22

### Bug Fixes

- fix not being able to find the dictionary on Android 10-12 - ([f154ca5](https://github.com/mumu-lhl/Ciyue/commit/f154ca594b840dcc40c0d977e236e7c9e6af5c71)) - Mumulhl

### Miscellaneous Chores

- **(deps)** bump drift_dev from 2.20.1 to 2.20.2 ([#11](https://github.com/mumu-lhl/Ciyue/issues/11)) - ([2369709](https://github.com/mumu-lhl/Ciyue/commit/2369709bdf8961ccd69fe9487fe07469c0020347)) - dependabot[bot]
- **(deps)** bump drift from 2.20.0 to 2.20.1 ([#10](https://github.com/mumu-lhl/Ciyue/issues/10)) - ([03fd19a](https://github.com/mumu-lhl/Ciyue/commit/03fd19aaf153b8e54cfe7ad84f599b306dee85d5)) - dependabot[bot]
- **(deps)** bump drift from 2.20.0 to 2.20.2 ([#13](https://github.com/mumu-lhl/Ciyue/issues/13)) - ([43b9403](https://github.com/mumu-lhl/Ciyue/commit/43b9403569807b4acd017488911b89ba6abc6f05)) - dependabot[bot]
- **(deps)** bump drift_dev from 2.20.2 to 2.20.3 ([#14](https://github.com/mumu-lhl/Ciyue/issues/14)) - ([8643ba3](https://github.com/mumu-lhl/Ciyue/commit/8643ba3db12419663097b657e77f72471f57cbfa)) - dependabot[bot]
- **(workflow)** fix workflow for pr - ([4656bb4](https://github.com/mumu-lhl/Ciyue/commit/4656bb4424420c8b7d9a4ff783036a5ff47bcb14)) - Mumulhl
- update pubspec.lock - ([f41d4d6](https://github.com/mumu-lhl/Ciyue/commit/f41d4d63880b812ddbea5f488d81d626eee9092a)) - Mumulhl

---
## [0.8.2](https://github.com/mumu-lhl/Ciyue/compare/v0.8.1..v0.8.2) - 2024-09-08

### Documentation

- **(readme)** add downloads badges - ([a88e087](https://github.com/mumu-lhl/Ciyue/commit/a88e087702f47a5f694a42abf5c865c7740c93cb)) - Mumulhl

### Miscellaneous Chores

- **(build)** change version code - ([944cdb9](https://github.com/mumu-lhl/Ciyue/commit/944cdb9e5fe9038369c536806bd735419f3e0232)) - Mumulhl
- **(workflow)** add dependabot - ([4288151](https://github.com/mumu-lhl/Ciyue/commit/42881513902366db8e4e2897c2ddff9893ded1c6)) - Mumulhl

---
## [0.8.1](https://github.com/mumu-lhl/Ciyue/compare/v0.8.0+19..v0.8.1) - 2024-09-08

### Documentation

- **(readme)** fix release link - ([db13a6e](https://github.com/mumu-lhl/Ciyue/commit/db13a6eec23fbf64b8ef876c6983489f1188ab86)) - Mumulhl

### Miscellaneous Chores

- **(workflow)** fix version code - ([479fd94](https://github.com/mumu-lhl/Ciyue/commit/479fd942e9c04bb64a69611b8e504782d2536cee)) - Mumulhl
- change the publish way - ([0c4e89b](https://github.com/mumu-lhl/Ciyue/commit/0c4e89bb143c66ded3d92d65097bdd634c5c7c79)) - Mumulhl
- fix VERSION_CODE is empty - ([c7cdda9](https://github.com/mumu-lhl/Ciyue/commit/c7cdda9629656121f6617f3a8d1f3c23ef5d0735)) - Mumulhl

---
## [0.8.0+19](https://github.com/mumu-lhl/Ciyue/compare/v0.7.1+18..v0.8.0+19) - 2024-09-07

### Features

- support long press copy on feedback and github buttons - ([2194f86](https://github.com/mumu-lhl/Ciyue/commit/2194f866751c75b44d4cb4569c714cf34a8fd1a6)) - Mumulhl
- support file selector for linux - ([0e3f9c1](https://github.com/mumu-lhl/Ciyue/commit/0e3f9c11fb6987b443d1d593f58e133eb3578663)) - Mumulhl

### Miscellaneous Chores

- **(workflow)** add different build number to different apks - ([604db64](https://github.com/mumu-lhl/Ciyue/commit/604db64f5ac5c5ccb48593d1697ed8b2ad58c0a4)) - Mumulhl
- upgrade package - ([b86b5bf](https://github.com/mumu-lhl/Ciyue/commit/b86b5bfe9662922614b9d455ce2ef22de9d71bed)) - Mumulhl

---
## [0.7.1+18](https://github.com/mumu-lhl/Ciyue/compare/v0.7.0+17..v0.7.1+18) - 2024-09-01

### Bug Fixes

- **(ui)** fix click theme and language chooser - ([7badd79](https://github.com/mumu-lhl/Ciyue/commit/7badd79aa42cfec0793187bfc622039e35e9e39b)) - Mumulhl

### Miscellaneous Chores

- **(changelog)** allow refactor in release changelog - ([25152ed](https://github.com/mumu-lhl/Ciyue/commit/25152ed9b040cea778532ac287c859edeb1db599)) - Mumulhl

### Refactoring

- **(ui)** version+buildNumber -> version (buildNumber) - ([e29c6aa](https://github.com/mumu-lhl/Ciyue/commit/e29c6aaf5d23608177f2aa9928f2186df8ea8c06)) - Mumulhl

---
## [0.7.0+17](https://github.com/mumu-lhl/Ciyue/compare/v0.6.0+16..v0.7.0+17) - 2024-09-01

### Documentation

- **(readme)** update wiki link - ([f7c86eb](https://github.com/mumu-lhl/Ciyue/commit/f7c86eb91a7127433941b05eb5c88a6d3419a552)) - Mumulhl
- **(readme)** add the usage of permissions - ([6668327](https://github.com/mumu-lhl/Ciyue/commit/6668327c139a78545319799b673709b36de2ffb5)) - Mumulhl
- **(readme)** fix position - ([a8cee22](https://github.com/mumu-lhl/Ciyue/commit/a8cee22445675172279219b8258e925014c8a243)) - Mumulhl
- **(readme)** add badges - ([e1e91c7](https://github.com/mumu-lhl/Ciyue/commit/e1e91c77e008b6afd726ad5c34496a6cf468e714)) - Mumulhl
- **(readme)** html to markdown - ([3b0af72](https://github.com/mumu-lhl/Ciyue/commit/3b0af72464cc88dadcb9ceeb5e536d3c264e65b1)) - Mumulhl

### Features

- add feedback and github link buttons - ([d3d97a9](https://github.com/mumu-lhl/Ciyue/commit/d3d97a99a3d76478e7bc560398d73e8a041c397a)) - Mumulhl

### Miscellaneous Chores

- **(workflow)** fix release changelog - ([3ec5131](https://github.com/mumu-lhl/Ciyue/commit/3ec513176328add7321ab6a678faeedf95163404)) - Mumulhl
- **(workflow)** add lock-threads - ([411ccbd](https://github.com/mumu-lhl/Ciyue/commit/411ccbd1e0ee68746b0d30c6400f8afe9211a8bc)) - Mumulhl
- upgrade packages - ([28c8a83](https://github.com/mumu-lhl/Ciyue/commit/28c8a83c8bd66dc0884988b0778fc44eb913a604)) - Mumulhl
- simplify AndroidManifest.xml - ([c1f6717](https://github.com/mumu-lhl/Ciyue/commit/c1f67179362e3286dd8934a9cc0a8e1776ad695a)) - Mumulhl

### Refactoring

- **(ui)** modify theme and language chooser - ([f2014d9](https://github.com/mumu-lhl/Ciyue/commit/f2014d9790b669cfa6249fb042a75d570c99bbbb)) - Mumulhl

---
## [0.6.0+16](https://github.com/mumu-lhl/Ciyue/compare/v0.4.3+14..v0.6.0+16) - 2024-08-27

### Documentation

- **(readme)** add Translation status - ([b2565f0](https://github.com/mumu-lhl/Ciyue/commit/b2565f0f25ea283247fc1efa445e1ca3d6803059)) - Mumulhl
- **(readme)** update install ([#4](https://github.com/mumu-lhl/Ciyue/issues/4)) - ([4add0df](https://github.com/mumu-lhl/Ciyue/commit/4add0df3c588d06c0738b3bd8e1e4ea5ae34076c)) - Poussinou
- **(readme)** update install in README_CN.md - ([043b3e5](https://github.com/mumu-lhl/Ciyue/commit/043b3e5db7df8350c2a030bff9a452bf1be02f55)) - Mumulhl
- **(readme)** remove 'Github Releases' in README_CN.md - ([183114e](https://github.com/mumu-lhl/Ciyue/commit/183114e81725e4d08db8f732c2a90d6c6ffe2309)) - Mumulhl
- **(readme)** add contributor - ([ab9529f](https://github.com/mumu-lhl/Ciyue/commit/ab9529f4d895ecb1261c22e185ce9a267435d849)) - Mumulhl
- **(readme)** update translation - ([ba06e09](https://github.com/mumu-lhl/Ciyue/commit/ba06e097c04622ec3e3ce3d4da186331e215a1ed)) - Mumulhl

### Features

- add Bokmål language - ([78151a2](https://github.com/mumu-lhl/Ciyue/commit/78151a2194db47aa0ab3b5af57966f3f96eb4b8f)) - Mumulhl
- add about button - ([c846220](https://github.com/mumu-lhl/Ciyue/commit/c846220066c68cb74a9c1eea97713b96fec498f2)) - Mumulhl
- add recommended dictionaries button - ([d93a561](https://github.com/mumu-lhl/Ciyue/commit/d93a561b511da74d6f0657e166601975d077a93f)) - Mumulhl

### Miscellaneous Chores

- **(l10n)** create app_nb.arb - ([b0ceb00](https://github.com/mumu-lhl/Ciyue/commit/b0ceb0052e2c226e58bb7e985f005a4c3421e480)) - Mumulhl
- **(l10n)** delete repeatable arb - ([9498ade](https://github.com/mumu-lhl/Ciyue/commit/9498ade1bbf94af4efd7367156b69f039d4f9015)) - Mumulhl
- **(workflow)** fix generate changelog push error - ([70a9c88](https://github.com/mumu-lhl/Ciyue/commit/70a9c88890fdce7b03d39225df1f2e2d17894916)) - Mumulhl
- **(workflow)** fix generate changelog push error again - ([5cc4400](https://github.com/mumu-lhl/Ciyue/commit/5cc4400af0d00651b7f31d003a7768900a47564c)) - Mumulhl
- **(workflow)** fix generate changelog push error again - ([502dcd6](https://github.com/mumu-lhl/Ciyue/commit/502dcd64e2b9371308a51b3aa8f36e63b19d6e72)) - Mumulhl
- **(workflow)** remove useless environment variable - ([3b7ba0d](https://github.com/mumu-lhl/Ciyue/commit/3b7ba0d3eb1d7c1da35f612494e12cd9215497bb)) - Mumulhl
- **(workflow)** push changelog commit by ad-m/github-push-action - ([69ada0c](https://github.com/mumu-lhl/Ciyue/commit/69ada0ccc93060cc2af957ee0c3ef05525cf2826)) - Mumulhl
- **(workflow)** update release - ([820560b](https://github.com/mumu-lhl/Ciyue/commit/820560bb2a481e7a1d7b4ce9e81833d6d3d98afc)) - Mumulhl
- **(workflow)** update release - ([3825e15](https://github.com/mumu-lhl/Ciyue/commit/3825e1552f7dfa07e1dfb0f21127f89d3aa46e47)) - Mumulhl
- **(workflow)** update release - ([3f749b0](https://github.com/mumu-lhl/Ciyue/commit/3f749b089416019a5993617ca921d6743034babb)) - Mumulhl
- **(workflow)** update release - ([a2c5f26](https://github.com/mumu-lhl/Ciyue/commit/a2c5f26cb7cd7d41fdb48115a1b04d448cb063ae)) - Mumulhl
- **(workflow)** update release - ([bd1f9b3](https://github.com/mumu-lhl/Ciyue/commit/bd1f9b3b253a5a040d32447dc894e7eae54d2057)) - Mumulhl
- **(workflow)** make flutter workflow work well when is triggered by pr - ([a49ba8e](https://github.com/mumu-lhl/Ciyue/commit/a49ba8e2a1fb1273c89bd04da89bcc9dc2e279db)) - Mumulhl
- **(workflow)** fix flutter_pr - ([113843d](https://github.com/mumu-lhl/Ciyue/commit/113843d08e5bc47e9a89a79e9513278805fe0305)) - Mumulhl
- **(workflow)** reduce release changelog - ([2018e6f](https://github.com/mumu-lhl/Ciyue/commit/2018e6feb3fef8505ae61a1d92ff06f0659c8327)) - Mumulhl
- remove code of conduct - ([08f9870](https://github.com/mumu-lhl/Ciyue/commit/08f987050878306e89da6b247a6afae547b9586c)) - Mumulhl
- upgrade packages - ([d3c486a](https://github.com/mumu-lhl/Ciyue/commit/d3c486a02744177a88c1b805eb89701b0ec43e99)) - Mumulhl
- upgrade packages - ([456ad7d](https://github.com/mumu-lhl/Ciyue/commit/456ad7d58ca02a31c844bcc01cc5740d9216f9eb)) - Mumulhl
- add issue templates - ([c5c4c42](https://github.com/mumu-lhl/Ciyue/commit/c5c4c423925e68d338a9ac0efc4b1d05c0b284af)) - Mumulhl

### Revert

- chore(workflow): give up to fix push error - ([1bae4c4](https://github.com/mumu-lhl/Ciyue/commit/1bae4c44a0733c32665f45dd4c0dfe6e7b912aab)) - Mumulhl

---
## [0.4.3+14](https://github.com/mumu-lhl/Ciyue/compare/v0.4.3+12..v0.4.3+14) - 2024-08-18

### Documentation

- generate changelog - ([2a3d5e7](https://github.com/mumu-lhl/Ciyue/commit/2a3d5e7130debcfc9a4c197fadbda6b3f00bb3fc)) - Mumulhl

### Miscellaneous Chores

- **(workflow)** generate CHANGELOG.md automatically - ([7b3e022](https://github.com/mumu-lhl/Ciyue/commit/7b3e02263ae0cd7ed4d0d85b9bafc7de1c17e310)) - Mumulhl
- **(workflow)** fix step - ([55f964d](https://github.com/mumu-lhl/Ciyue/commit/55f964dfa0b250d8ea1607a7ad7a252ec6e36e3c)) - Mumulhl
- **(workflow)** fix path - ([4a18014](https://github.com/mumu-lhl/Ciyue/commit/4a18014c31f1dc04e1725a3450f3fc1777e04d9a)) - Mumulhl
- **(workflow)** try to fix push error - ([959634d](https://github.com/mumu-lhl/Ciyue/commit/959634dbda79095ab6c9937719904910ba252090)) - Mumulhl
- **(workflow)** give up to fix push error - ([64c299b](https://github.com/mumu-lhl/Ciyue/commit/64c299bf32f33bc6f5088e51989acd28729bb010)) - Mumulhl
- **(workflow)** checkout when build starts - ([cb896a4](https://github.com/mumu-lhl/Ciyue/commit/cb896a42412397295fab108e8bd1337fa9180d59)) - Mumulhl

---
## [0.4.3+12](https://github.com/mumu-lhl/Ciyue/compare/v0.4.2+11..v0.4.3+12) - 2024-08-18

### Revert

- chore: remove Internet permission - ([8d8f1be](https://github.com/mumu-lhl/Ciyue/commit/8d8f1be5f7f97fd6da23988f9e8953e6f99feb35)) - Mumulhl

---
## [0.4.2+11](https://github.com/mumu-lhl/Ciyue/compare/v0.4.1+5..v0.4.2+11) - 2024-08-18

### Documentation

- **(readme)** add Recommended Dictionaries - ([80217be](https://github.com/mumu-lhl/Ciyue/commit/80217bee9e0eb8f5f0f4cd151b6fc4c0734668d8)) - Mumulhl
- add code of conduct - ([9dacdfd](https://github.com/mumu-lhl/Ciyue/commit/9dacdfd913c8fdb5f8279c3e7b772e32050b5365)) - Mumulhl

### Miscellaneous Chores

- **(l10n)** remove app_zh_CN.arb - ([78d356b](https://github.com/mumu-lhl/Ciyue/commit/78d356b3f3a45a8976556226731bc14c64484943)) - Mumulhl
- **(workflow)** add changelog to release - ([939baad](https://github.com/mumu-lhl/Ciyue/commit/939baad03b9d708a3538b1c8de02abeeaf3fa9b2)) - Mumulhl
- **(workflow)** generate CHANGELOG.md automatically - ([ab75fa7](https://github.com/mumu-lhl/Ciyue/commit/ab75fa7ab7b2b9b18c218cd7b8c77b913d4eed80)) - Mumulhl
- **(workflow)** fix commit changelog - ([4bdf29a](https://github.com/mumu-lhl/Ciyue/commit/4bdf29a3715372b830ca1e1cf64e5eacb91150f3)) - Mumulhl
- **(workflow)** fix src refspec main does not match any - ([8021984](https://github.com/mumu-lhl/Ciyue/commit/8021984d232b087e6a69fd28651009a7f76f7254)) - Mumulhl
- **(workflow)** remove generate CHANGELOG.md - ([9d39ab1](https://github.com/mumu-lhl/Ciyue/commit/9d39ab105fd12bc81cb4c58dbcd6cd818250c3b0)) - Mumulhl
- **(workflow)** add needs - ([0f34370](https://github.com/mumu-lhl/Ciyue/commit/0f34370e06cfe1400b0f42b2ccdbe3b68cc008e2)) - Mumulhl
- **(workflow)** restore release workflow - ([4d32f06](https://github.com/mumu-lhl/Ciyue/commit/4d32f06604749b8b2f9972348559e919affad2e6)) - Mumulhl
- remove Internet permission - ([05abe59](https://github.com/mumu-lhl/Ciyue/commit/05abe59d022d0a2063c4cdde826bdda11e2c7c66)) - Mumulhl

---
## [0.4.1+5](https://github.com/mumu-lhl/Ciyue/compare/v0.4.0+1..v0.4.1+5) - 2024-08-18

### Documentation

- **(readme)** add features - ([9b14f30](https://github.com/mumu-lhl/Ciyue/commit/9b14f30d1453b6c656817dfdc713149cc7cde331)) - Mumulhl
- **(readme)** add features - ([6a6555c](https://github.com/mumu-lhl/Ciyue/commit/6a6555c0b29868ea0416c3fd4a9eaf4da65b77ff)) - Mumulhl

### Miscellaneous Chores

- **(workflow)** add flutter-version - ([b1ee295](https://github.com/mumu-lhl/Ciyue/commit/b1ee295a0b7231a7ae2fe40109bbca35eccc82b3)) - Mumulhl
- **(workflow)** fix flutter-version - ([bfdb7f2](https://github.com/mumu-lhl/Ciyue/commit/bfdb7f2de49bb24fa479918dfbf6caab6fcb6617)) - Mumulhl
- **(workflow)** add universal apk - ([7bfbab6](https://github.com/mumu-lhl/Ciyue/commit/7bfbab65b27fd10e8e75bbf235911642b0476fed)) - Mumulhl
- change package name - ([ab9c4aa](https://github.com/mumu-lhl/Ciyue/commit/ab9c4aabf32cc9ce4d31139d6c40c9b3cbfbfc15)) - Mumulhl
- add flutter submodule - ([452361a](https://github.com/mumu-lhl/Ciyue/commit/452361ae707ef87d354a62b57528756562021db6)) - Mumulhl
- add metadata - ([dee13b0](https://github.com/mumu-lhl/Ciyue/commit/dee13b032ec6faacb4ed08b6af44c2d7f30b4860)) - Mumulhl

### Revert

- chore: add flutter submodule - ([9e73f92](https://github.com/mumu-lhl/Ciyue/commit/9e73f92936d7c3060fdc7222ab0c5c4414c0d2a4)) - Mumulhl

---
## [0.4.0+1](https://github.com/mumu-lhl/Ciyue/compare/v0.3.0+1..v0.4.0+1) - 2024-08-17

### Bug Fixes

- load some mdx files failed - ([987f4ce](https://github.com/mumu-lhl/Ciyue/commit/987f4ce838009ac6dca256c79b459de213a0490c)) - Mumulhl

### Features

- support splashscreen - ([5a8cca2](https://github.com/mumu-lhl/Ciyue/commit/5a8cca26a34fbce50ea27b72729addd963ecfd45)) - Mumulhl
- support bigger mdx dictionaries - ([ed86c21](https://github.com/mumu-lhl/Ciyue/commit/ed86c215d8f85adf803342a8886c470460e272d0)) - Mumulhl
- add remove button to search - ([f8b8db8](https://github.com/mumu-lhl/Ciyue/commit/f8b8db89ad14128c2e81642e4148ade1e9b55796)) - Mumulhl

---
## [0.3.0+1](https://github.com/mumu-lhl/Ciyue/compare/v0.2.1+5..v0.3.0+1) - 2024-08-17

### Features

- support more mdx files - ([94ad594](https://github.com/mumu-lhl/Ciyue/commit/94ad5943f43e3913dc640075725f870e39ff05b6)) - Mumulhl
- add read loudly button to display word - ([73c0bde](https://github.com/mumu-lhl/Ciyue/commit/73c0bde0fc20a716d154d7c8760f58cb65f6238a)) - Mumulhl
- add read loudly button to search result - ([46982ab](https://github.com/mumu-lhl/Ciyue/commit/46982ab99e62b3fe982d700f6a39dc141cad4ac7)) - Mumulhl

### Miscellaneous Chores

- update pubspec.lock - ([4bb01a1](https://github.com/mumu-lhl/Ciyue/commit/4bb01a16025258216412da7384783501001c5442)) - Mumulhl

---
## [0.2.1+5](https://github.com/mumu-lhl/Ciyue/compare/v0.2.0+1..v0.2.1+5) - 2024-08-16

### Bug Fixes

- stop CircularProgressIndicator when load mdx file failed - ([8d41626](https://github.com/mumu-lhl/Ciyue/commit/8d416260a69d8aa961abf2403e54d5afcaa5366d)) - Mumulhl

### Documentation

- add license - ([05ee2e0](https://github.com/mumu-lhl/Ciyue/commit/05ee2e0d74dde9e3c94ef338b60d82682d7bd027)) - Mumulhl

### Miscellaneous Chores

- **(action)** fix keystore path - ([03447e1](https://github.com/mumu-lhl/Ciyue/commit/03447e1bbfd76aedbcd9854d3170772902b92343)) - Mumulhl
- **(workflow)** don't run flutter.yml on tag creation - ([63818c0](https://github.com/mumu-lhl/Ciyue/commit/63818c08a57be7bf6b67a8f7d1a5eada010fa747)) - Mumulhl
- **(workflow)** fix key properties path - ([5ed6e98](https://github.com/mumu-lhl/Ciyue/commit/5ed6e98cdb518d5c70028f59e519ce6323323f11)) - Mumulhl
- **(workflow)** fix keystore path - ([3fddd9b](https://github.com/mumu-lhl/Ciyue/commit/3fddd9bb33d93b0e2c7f4407c66bcb634a0cc042)) - Mumulhl
- fix create key.properties - ([d16efbe](https://github.com/mumu-lhl/Ciyue/commit/d16efbef287bc009c0beba67a81eba5556d71bae)) - Mumulhl
- fix sign - ([44f64d7](https://github.com/mumu-lhl/Ciyue/commit/44f64d7073bb49a205f8f7b8a69108cb760712dc)) - Mumulhl
- fix sign - ([87975a2](https://github.com/mumu-lhl/Ciyue/commit/87975a20e2111b7c95e839898f75230c8cbd7486)) - Mumulhl

### Revert

- chore(workflow): don't run flutter.yml on tag creation - ([ec3af4a](https://github.com/mumu-lhl/Ciyue/commit/ec3af4a5c189289495454fd4766edf7661b8b9a5)) - Mumulhl

---
## [0.2.0+1](https://github.com/mumu-lhl/Ciyue/compare/v0.0.1+4..v0.2.0+1) - 2024-08-16

### Bug Fixes

- **(l10n)** fix text for 'not support' - ([83a8e31](https://github.com/mumu-lhl/Ciyue/commit/83a8e3147b515576a9f8257f551e446024b298a9)) - Mumulhl
- language and theme PopupMenuButton Icon - ([02c420e](https://github.com/mumu-lhl/Ciyue/commit/02c420ed858b7a4dfe27cf28cfe6bf629edd9683)) - Mumulhl
- entry scheme for word that longer than two words - ([39f397f](https://github.com/mumu-lhl/Ciyue/commit/39f397f14f8efca51c5ca40ff7ed61d5dd0225db)) - Mumulhl
- show unsupportable mdx file - ([f94439f](https://github.com/mumu-lhl/Ciyue/commit/f94439fded76141dddb19004c0387c5fecfae663)) - Mumulhl

### Documentation

- add install - ([e28c1ab](https://github.com/mumu-lhl/Ciyue/commit/e28c1ab7b8bdee45b3e7129b177e59500fbcc3c6)) - Mumulhl
- add screenshots - ([2d95324](https://github.com/mumu-lhl/Ciyue/commit/2d953244be6a793538aec15c850aa87dc2391ca3)) - Mumulhl
- add language switch - ([0dbc085](https://github.com/mumu-lhl/Ciyue/commit/0dbc08506505793c856ab3b1865d89f3f1c9ba0f)) - Mumulhl
- fix images - ([9a15975](https://github.com/mumu-lhl/Ciyue/commit/9a159759f2a2bb3cdcb614a93456cc9392f9b3ce)) - Mumulhl
- fix images - ([a1466e3](https://github.com/mumu-lhl/Ciyue/commit/a1466e3366202177dc618a1f994484d7be76a739)) - Mumulhl
- fix images - ([6296732](https://github.com/mumu-lhl/Ciyue/commit/6296732bd47bd2d7b3173ccb302607705d1f43be)) - Mumulhl

### Features

- read resources directly if there is no mdd - ([8d1d326](https://github.com/mumu-lhl/Ciyue/commit/8d1d326b80cc9be4df57622f7b8068a8eeb41d82)) - Mumulhl
- remove html package - ([b6efedd](https://github.com/mumu-lhl/Ciyue/commit/b6efedd321ee100cdd135d4fa72d4034d80e9ae8)) - Mumulhl
- support lookup in context menu - ([0a1e584](https://github.com/mumu-lhl/Ciyue/commit/0a1e584146ec1190269385ec452d97d2e9a760e3)) - Mumulhl
- hide system context menu items - ([7c618bb](https://github.com/mumu-lhl/Ciyue/commit/7c618bbbf178426fe4b8deed9e54c47bd1ecfd2e)) - Mumulhl
- support tts - ([dfe9ee2](https://github.com/mumu-lhl/Ciyue/commit/dfe9ee209a5331e94b27a0d3681402aa6bc99b35)) - Mumulhl

### Miscellaneous Chores

- **(v0.2.0+1)** release v0.2.0+1 - ([d502e9a](https://github.com/mumu-lhl/Ciyue/commit/d502e9a6d633d63db6f2c709a927016e2fd840bf)) - Mumulhl
- disable flutter workflow for tag push - ([328ed60](https://github.com/mumu-lhl/Ciyue/commit/328ed60757f029ec2164d273130f8a409ae1d198)) - Mumulhl
- disable **.md for flutter workflow - ([d281da8](https://github.com/mumu-lhl/Ciyue/commit/d281da80db81262ef03b49c1ae843e28a17c15a0)) - Mumulhl
- fix flutter workflow - ([96dab2f](https://github.com/mumu-lhl/Ciyue/commit/96dab2f28ee6a0e1708cc201a6449189a5a87d10)) - Mumulhl
- add cliff - ([fd0145d](https://github.com/mumu-lhl/Ciyue/commit/fd0145de8545ccdd697d528c61a38b1114c9477b)) - Mumulhl
- upload to artifact after building - ([fac2d14](https://github.com/mumu-lhl/Ciyue/commit/fac2d1431cc0f9668eba322a5ce8401cb25f84cd)) - Mumulhl
- release v0.1.0+1 - ([fa7e180](https://github.com/mumu-lhl/Ciyue/commit/fa7e18073c4606c0e1f7be70f895a0a9f202cef0)) - Mumulhl

### Style

- sort members - ([00b5dfc](https://github.com/mumu-lhl/Ciyue/commit/00b5dfcdd67693d0851da93762ebfe646b395ceb)) - Mumulhl

---
## [0.0.1+4] - 2024-08-15

### Documentation

- update readme - ([bd6640e](https://github.com/mumu-lhl/Ciyue/commit/bd6640e2063b10801b4e92741c66ddb47eebe44b)) - Mumulhl

### Miscellaneous Chores

- **(action)** fix JDK version - ([6c9c843](https://github.com/mumu-lhl/Ciyue/commit/6c9c843e86c0aa0f82183e3f71ea390445787aa6)) - Mumulhl
- **(action)** fix JDK version to 17 - ([4b880bc](https://github.com/mumu-lhl/Ciyue/commit/4b880bcf50042f75e48ef2fb86237b050e484c31)) - Mumulhl
- **(action)** update setup-java version - ([2e4749d](https://github.com/mumu-lhl/Ciyue/commit/2e4749da8e3381271ec1ad75f31657b74ee6da33)) - Mumulhl
- initialize - ([692c168](https://github.com/mumu-lhl/Ciyue/commit/692c168cb6dc6be46469bbdcdc2e4d0f5085cc8f)) - Mumulhl
- update description - ([791d2a2](https://github.com/mumu-lhl/Ciyue/commit/791d2a2a85bdd63e810f8c7e14fe27e6cab3fc3e)) - Mumulhl
- add LICENSE - ([b5e02cf](https://github.com/mumu-lhl/Ciyue/commit/b5e02cf17af2a48e0252c86cc4ff6a9a7702b311)) - Mumulhl
- add commitlint workflow - ([963a348](https://github.com/mumu-lhl/Ciyue/commit/963a348053259475bd972a4e8aa74e0ef5d0d630)) - Mumulhl
- add dart workflow - ([bd698eb](https://github.com/mumu-lhl/Ciyue/commit/bd698eb95ce6332ec2b5af68ec8312b08eac8ef6)) - Mumulhl
- update package name - ([c79858c](https://github.com/mumu-lhl/Ciyue/commit/c79858c01ba309ee452fa9355c05af5b9a7a9931)) - Mumulhl
- change dart to flutter workflow - ([9e8eca7](https://github.com/mumu-lhl/Ciyue/commit/9e8eca7a091bbb5d89b3a86cbc4758e2fa0e1d4f)) - Mumulhl
- update l10n - ([cbe4923](https://github.com/mumu-lhl/Ciyue/commit/cbe4923ffcc20b9e729006daf7dedade4cafd13d)) - Mumulhl
- add release workflow - ([fa17159](https://github.com/mumu-lhl/Ciyue/commit/fa17159b9e44310af88e06c37d931b86a5970d78)) - Mumulhl
- change workflow name of release.yml - ([1166b74](https://github.com/mumu-lhl/Ciyue/commit/1166b7414ef018df329d99aef78134d6dc628e92)) - Mumulhl
- fix rename for release.yml - ([287e542](https://github.com/mumu-lhl/Ciyue/commit/287e54220a1d2b557a46ead9b2932e061c6e67fc)) - Mumulhl
- fix rename for release.yml - ([1a7d860](https://github.com/mumu-lhl/Ciyue/commit/1a7d8604dd322221267c693e0ae08aa52002960f)) - Mumulhl
- update build version - ([ee51e11](https://github.com/mumu-lhl/Ciyue/commit/ee51e115ee7e448466f5273b5fdeb3ff2aa9eef0)) - Mumulhl
- fix rename aab - ([51dafa9](https://github.com/mumu-lhl/Ciyue/commit/51dafa96898a28a1447ccdf226447ffec14cd9c7)) - Mumulhl
- update build version - ([2b877f4](https://github.com/mumu-lhl/Ciyue/commit/2b877f41fa5164305fa087fcddd8fb064bf1c8b9)) - Mumulhl
- fix release workflow token - ([d1a72c8](https://github.com/mumu-lhl/Ciyue/commit/d1a72c8ec94109d6afe2d0b76dcddfa90e102386)) - Mumulhl
- update build version - ([0b0202c](https://github.com/mumu-lhl/Ciyue/commit/0b0202c46903c6822fe8b50ae9c02d3c18bf9b6a)) - Mumulhl

<!-- generated by git-cliff -->
