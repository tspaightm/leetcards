import "package:tuple/tuple.dart";

class FundamentalFlashcard
{
  final String m_Id;
  final List<String> m_Topics;
  final String m_Question;
  final List<Tuple2<String, bool>> m_Options;
  final String m_Explanation;

  FundamentalFlashcard
  ({
    required this.m_Id,
    required this.m_Topics,
    required this.m_Question,
    required this.m_Options,
    required this.m_Explanation,
  });
}
