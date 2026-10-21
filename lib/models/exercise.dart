class ExerciseStep {
  final String key;
  final String title;
  final String? placeholder;
  final int? count;

  const ExerciseStep({
    required this.key,
    required this.title,
    this.placeholder,
    this.count,
  });
}

class Exercise {
  final String id;
  final String name;
  final String subtitle;
  final int minutes;
  final String icon;
  final String description;
  final List<ExerciseStep> steps;

  const Exercise({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.minutes,
    required this.icon,
    required this.description,
    required this.steps,
  });

  static const Map<String, Exercise> all = {
    'grounding': Exercise(
      id: 'grounding',
      name: 'Neo về hiện tại',
      subtitle: '5-4-3-2-1',
      minutes: 2,
      icon: 'ground',
      description: 'Kết nối lại với hiện tại.',
      steps: [
        ExerciseStep(key: 'sense', count: 5, title: '5 thứ bạn nhìn thấy'),
        ExerciseStep(key: 'sense', count: 4, title: '4 thứ bạn chạm vào'),
        ExerciseStep(key: 'sense', count: 3, title: '3 âm thanh bạn nghe'),
        ExerciseStep(key: 'sense', count: 2, title: '2 mùi hương bạn ngửi'),
        ExerciseStep(key: 'sense', count: 1, title: '1 vị bạn nếm'),
      ],
    ),
    'reframe': Exercise(
      id: 'reframe',
      name: 'Nhìn lại suy nghĩ',
      subtitle: 'Tái cấu trúc suy nghĩ',
      minutes: 3,
      icon: 'reframe',
      description: 'Tìm một cách nhìn cân bằng hơn.',
      steps: [
        ExerciseStep(
          key: 'write',
          title: 'Suy nghĩ đó là gì?',
          placeholder: 'Viết vài từ...',
        ),
        ExerciseStep(
          key: 'write',
          title: 'Điều gì ủng hộ nó?',
          placeholder: 'Điều đã thật sự xảy ra...',
        ),
        ExerciseStep(
          key: 'write',
          title: 'Điều gì chưa ủng hộ nó?',
          placeholder: 'Điều cho thấy bức tranh khác...',
        ),
        ExerciseStep(
          key: 'write',
          title: 'Bạn sẽ nói gì với một người bạn?',
          placeholder: 'Mình sẽ nói…',
        ),
        ExerciseStep(
          key: 'write',
          title: 'Một cách nhìn cân bằng hơn?',
          placeholder: 'Có thể mình…',
        ),
      ],
    ),
    'compassion': Exercise(
      id: 'compassion',
      name: 'Lời dịu dàng',
      subtitle: 'Tự thấu cảm',
      minutes: 3,
      icon: 'heart',
      description: 'Nói với mình bằng giọng dịu dàng.',
      steps: [
        ExerciseStep(
          key: 'write',
          title: 'Bạn sẽ nói gì với một người bạn thân?',
          placeholder: 'Mình sẽ nói…',
        ),
        ExerciseStep(
          key: 'write',
          title: 'Nói lại điều đó với chính mình',
          placeholder: 'Mình cũng xứng đáng…',
        ),
      ],
    ),
    'pause': Exercise(
      id: 'pause',
      name: 'Khoảng dừng',
      subtitle: 'Trước khi đáp lại',
      minutes: 2,
      icon: 'pause',
      description: 'Dừng vài nhịp trước khi đáp lại.',
      steps: [
        ExerciseStep(key: 'stop', title: 'Dừng lại'),
        ExerciseStep(key: 'breath', title: 'Thở chậm ba lần'),
        ExerciseStep(key: 'name', title: 'Gọi tên cảm xúc'),
        ExerciseStep(
          key: 'write',
          title: 'Điều gì quan trọng lúc này?',
          placeholder: 'Điều mình quan tâm là…',
        ),
        ExerciseStep(key: 'choose', title: 'Bạn muốn làm gì tiếp?'),
      ],
    ),
  };

  static Exercise get(String id) => all[id] ?? all['grounding']!;
}
