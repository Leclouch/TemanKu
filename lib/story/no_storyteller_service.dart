import 'package:temanku/story/storyteller_service.dart';

/// Default [StorytellerService] binding — **wired as the default in
/// `core/service_locator.dart`.**
///
/// Local, instant, no network call — every child gets this until a guardian
/// both opts in (`Child.storytellerEnabled`) and the build carries an API
/// key. Same "off must be free" reasoning as [NoHintService]: leaving the
/// feature off must never cost a day-arc render anything.
///
/// Not a stub pretending to be the real feature — this is a real, if plainer,
/// implementation of the same contract. A handful of hand-written templates,
/// picked deterministically from ([StoryContext.childName], the module, and
/// the tier), give the day-arc screen genuine varied flavor text with zero
/// setup. Swapping in `ClaudeStorytellerService` later makes the line fresh
/// per session instead of fixed per (child, module, tier) — a richer version
/// of the same feature, not a different one.
class NoStorytellerService implements StorytellerService {
  const NoStorytellerService();

  static const _milestoneLines = [
    '{name} baru saja menguasai babak ini — petualangan {module} lanjut ke tantangan baru!',
    'Satu babak selesai! {name} sudah siap untuk cerita {module} berikutnya.',
    'Hebat, {name}! Babak {module} ini sudah dikuasai sepenuhnya.',
  ];

  static const _practiceLines = [
    '{name} sedang di tengah petualangan {module}, {tier}.',
    'Babak {module} hari ini: {name} {tier}.',
    'Cerita {module} {name} berlanjut — sekarang {tier}.',
  ];

  @override
  Future<String?> nextBeat(StoryContext context) async {
    final pool = context.mastered ? _milestoneLines : _practiceLines;
    final template = pool[_pick(context, pool.length)];
    return template
        .replaceAll('{name}', context.childName)
        .replaceAll('{module}', context.module.displayName)
        .replaceAll('{tier}', context.tierCopy);
  }

  /// A stable, non-cryptographic index so the same (child, module, tier)
  /// combination reads the same line across rebuilds within a session,
  /// rather than flickering between templates on every frame.
  int _pick(StoryContext context, int poolSize) {
    final key = '${context.childName}|${context.module.id}|${context.tierCopy}';
    return key.hashCode.abs() % poolSize;
  }
}
