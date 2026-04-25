import "package:tuple/tuple.dart";

class AlgorithmFlashcard
{
  final String m_Id;
  final String m_Title;
  final String m_Description;
  final List<AlgorithmFlashcardExample> m_Examples;
  final List<String> m_Constraints;
  final List<String> m_Topics;
  final List<AlgorithmFlashcardQuestion> m_Questions;
  final String m_Explanation;

  AlgorithmFlashcard
  ({
    required this.m_Id,
    required this.m_Title,
    required this.m_Description,
    required this.m_Examples,
    required this.m_Constraints,
    required this.m_Topics,
    required this.m_Questions,
    required this.m_Explanation
  });
}

class AlgorithmFlashcardExample
{
  final String m_Input;
  final String m_Output;
  final String m_Explanation;

  AlgorithmFlashcardExample
  ({
    required this.m_Input,
    required this.m_Output,
    required this.m_Explanation
  });

  factory AlgorithmFlashcardExample.fromMap(Map<String, dynamic> map)
  {
    return AlgorithmFlashcardExample(
      m_Input: map['input'] as String,
      m_Output: map['output'] as String,
      m_Explanation: (map['explanation'] as String?) ?? '');
  }
}

class AlgorithmFlashcardQuestion
{
  final String m_Question;
  final List<Tuple2<String, bool>> m_Options;

  AlgorithmFlashcardQuestion
  ({
    required this.m_Question,
    required this.m_Options
  });

  factory AlgorithmFlashcardQuestion.fromMap(Map<String, dynamic> map)
  {
    final optionsRaw = map['options'] as List<dynamic>;
    final optionsParsed = optionsRaw.map((e)
    {
      final m = e as Map<String, dynamic>;
      return Tuple2<String, bool>(m['option'] as String, m['correct'] as bool);
    }).toList();

    optionsParsed.shuffle();
    return AlgorithmFlashcardQuestion(
      m_Question: map['question'] as String,
      m_Options: optionsParsed);
  }
}
