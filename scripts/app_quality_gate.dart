import 'dart:io';

const List<String> _scanRoots = <String>['lib', 'test'];

void main() {
  final List<String> failures = <String>[];
  _scanForRawColors(failures);
  _scanForRequiredDocs(failures);

  if (failures.isNotEmpty) {
    stderr.writeln('Quality gate failed:');
    for (final String failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Quality gate passed');
}

void _scanForRawColors(List<String> failures) {
  final RegExp rawColor = RegExp(r'Color\(\s*0x');
  for (final File file in _dartFiles()) {
    final String path = file.path;
    if (path.endsWith('lib/theme/design_tokens.dart')) {
      continue;
    }
    final List<String> lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i += 1) {
      if (rawColor.hasMatch(lines[i])) {
        failures.add('$path:${i + 1} uses raw Color(0x...) outside tokens');
      }
    }
  }
}

void _scanForRequiredDocs(List<String> failures) {
  const List<String> required = <String>[
    'docs/performance-budget.md',
    'docs/device-validation-matrix.md',
    'docs/ui/design-spec.md',
  ];
  for (final String path in required) {
    if (!File(path).existsSync()) {
      failures.add('$path is required for release QA');
    }
  }
}

Iterable<File> _dartFiles() sync* {
  for (final String root in _scanRoots) {
    final Directory directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    yield* directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'));
  }
}
