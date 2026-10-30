# IPTV Player (Stalker/MAC)

## بناء الـ IPA بدون ماك
1. أنشئ مستودع GitHub جديد وارفع محتويات هذا المجلد.
2. تبويب Actions ← Build IPA ← Run workflow.
3. حمّل IPTVPlayer.ipa من Artifacts (غير موقّع).
4. ثبّته بالجوال عبر Sideloadly أو AltStore (يوقّعه بحساب Apple ID).

## بناء بالماك
brew install xcodegen && xcodegen generate && open IPTVPlayer.xcodeproj
