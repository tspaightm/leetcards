import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";

MarkdownStyleSheet markdownStyleSheet(BuildContext context, double? fontSize)
{
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final Color textColor = isDark ? Colors.white : Colors.black87;
  final base = MarkdownStyleSheet.fromTheme(Theme.of(context));

  return base.copyWith(
    p: TextStyle(fontSize: fontSize, color: textColor, height: 1.5),
    strong: TextStyle(fontSize: fontSize, color: textColor, fontWeight: FontWeight.bold),
    em: TextStyle(fontSize: fontSize, color: textColor, fontStyle: FontStyle.italic),
    code: TextStyle(
      fontFamily: "Inconsolata",
      fontSize: fontSize,
      color: textColor),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: isDark ? Colors.grey[850] : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8)),
    blockSpacing: 8,
    listIndent: 16);
}

Widget markdownBody(BuildContext context, String text, double? fontSize)
{
  return MarkdownBody(
    data: text,
    styleSheet: markdownStyleSheet(context, fontSize),
    shrinkWrap: true);
}
