const askHawFlowContractFixture = <String, dynamic>{
  'version': 1,
  'guidance': 'Make room for unhurried practice. Keep each choice deliberate.',
  'adaptations': ['shorten', 'reschedule', 'skip', 'pause', 'resume'],
  'steps': [
    {
      'id': 'prepare',
      'title': 'Prepare your reading place',
      'guidance': 'Set aside the book and a quiet place to read.',
      'minutes': 20,
      'prerequisites': [],
      'completionMeaning': 'The book and place are ready.',
      'recoveryGuidance': 'Return to the place you chose; adjust it if needed.',
      'alternatives': [
        {
          'id': 'brief',
          'label': 'A small beginning',
          'minutes': 5,
          'guidance': 'Choose one page and put the book where you will see it.',
          'countsAsCompletion': true,
        },
      ],
    },
    {
      'id': 'read',
      'title': 'Spend time with the text',
      'guidance': 'Read slowly. Keep one sentence to return to.',
      'minutes': 30,
      'prerequisites': ['prepare'],
      'completionMeaning': 'Read the selected passage and keep one sentence.',
      'recoveryGuidance': 'Revisit your last sentence before continuing.',
      'alternatives': [],
    },
  ],
};
