import "dart:io";

import "package:ciyue/services/dictionary.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

Future<List<String>> findMddAudioFilesOnAndroid() async {
  final documentsDir =
      Directory(join((await getApplicationSupportDirectory()).path, "audios"));
  final mddFiles = <String>[];
  await findAllFileByExtension(documentsDir, mddFiles, "mdd");
  return mddFiles;
}
