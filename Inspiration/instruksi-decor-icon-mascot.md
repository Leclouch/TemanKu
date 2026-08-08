# Instruksi buat Claude Code: Decor, Icon, & Mascot

## Konteks
App terapi artikulasi wicara untuk anak SLB (non-verbal/neurodivergent). Desain UI
yang ada sekarang dinilai masih sangat kasar/belum jadi ("terrible") — mau di-overhaul.
Arah gaya keseluruhan: calm, editorial, photography-driven, referensi maximatherapy.com/programs/18-to-65.
Pengecualian: ada satu karakter mascot yang boleh lebih ekspresif, khusus buat membimbing
anak selama sesi latihan — bukan buat dekorasi umum.

## 3 kategori asset

**Decor umum** — dari Haikei (app.haikei.app), generator shape/wave/gradient-mesh.
Warna di-set manual ke token palette, export SVG. Cukup 5-8 variasi; sisanya Claude Code
compose ulang dari shape yang sama (scale/rotate/opacity) daripada bikin file baru terus.

**Vector icon** — dari Phosphor Icons atau Lucide, diinstall sebagai package
(`phosphor_flutter` di pubspec.yaml), bukan didownload satuan. Pilih SATU family
saja (jangan campur beberapa icon set) biar stroke-width & sudutnya konsisten
kayak di referensi Maxima.

**Mascot pembimbing anak** — dari Blush (blush.design), composer karakter dengan
beberapa pose (menyapa, memberi instruksi, merayakan jawaban benar, mendorong coba
lagi). Warna dikustom ke token palette yang sama, tapi boleh sedikit lebih hidup/
ekspresif dibanding elemen lain karena fungsinya spesifik buat anak. Dipakai HANYA
di flow latihan/interaksi anak — bukan di halaman admin, settings, atau bagian lain.

## Prompt lengkap ke Claude Code

```
Konteks: aplikasi terapi artikulasi wicara untuk anak SLB (non-verbal/neurodivergent).
Desain UI yang ada sekarang masih sangat kasar/belum jadi, mau di-overhaul total.

Referensi gaya: [screenshot Maxima Therapy — drag/paste di sini]
Arah: calm, editorial, photography-driven untuk keseluruhan app — TAPI ada satu
karakter mascot yang lebih ekspresif khusus buat membimbing anak selama sesi
latihan (pose: menyapa, memberi instruksi, merayakan jawaban benar, mendorong
coba lagi).

Design tokens (dari inspect element situs referensi):
- Warna: primary #______, background #______, text #______, accent #______
- Font: heading "______", body "______"
- Border-radius: ___px, spacing: 8/16/24/32

Asset yang tersedia:
- Decor/background shape: ./design-reference/decor-shapes/ (5-8 SVG dari Haikei,
  warna sudah di-set ke token di atas)
- Icon: package [phosphor_flutter/lucide] sudah terinstall — pilih dari situ,
  jangan generate/download icon baru
- Mascot: 3-5 pose PNG/SVG dari Blush di ./design-reference/mascot/, warna
  sudah dicustom ke token di atas

Tolong:
1. Audit dulu screen yang ada sekarang, list bagian mana yang paling "terrible"
   dan kenapa (sebelum mulai redesign, biar kita sepakat prioritas)
2. Propose layout baru untuk 1 screen contoh dulu (bukan langsung semua), pakai
   token + decor shape + icon + mascot di atas
3. Setelah saya approve, baru rollout pola yang sama ke screen lain
4. Mascot HANYA dipakai di flow latihan/interaksi anak, jangan ditaro di halaman
   admin/settings/dsb
```
