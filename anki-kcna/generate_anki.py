#!/usr/bin/env python3
"""Generate Anki decks from KCNA quiz JSON files."""

import json
import hashlib
import os
import sys
from pathlib import Path

# genanki is needed - we'll use a simple text-based format if not available
try:
    import genanki
    HAS_GENANKI = True
except ImportError:
    HAS_GENANKI = False


def generate_model_id(name):
    """Generate a stable model ID from name."""
    return int(hashlib.md5(name.encode()).hexdigest()[:8], 16)


def generate_deck_id(name):
    """Generate a stable deck ID from name."""
    return int(hashlib.md5(name.encode()).hexdigest()[:8], 16)


def create_anki_deck_genanki(quiz_data, output_path):
    """Create .apkg file using genanki."""
    quiz_num = quiz_data['quiz']
    questions = quiz_data['questions']

    model = genanki.Model(
        generate_model_id(f'KCNA Quiz {quiz_num}'),
        f'KCNA Practice Exam {quiz_num}',
        fields=[
            {'name': 'Question'},
            {'name': 'Answer'},
            {'name': 'Options'},
            {'name': 'Explanation'},
            {'name': 'Domain'},
        ],
        templates=[
            {
                'name': 'KCNA Card',
                'qfmt': '''
<div class="domain">{{Domain}}</div>
<div class="question">{{Question}}</div>
<hr>
<div class="options">{{Options}}</div>
''',
                'afmt': '''
{{FrontSide}}
<hr id="answer">
<div class="correct-answer">✅ {{Answer}}</div>
<div class="explanation">{{Explanation}}</div>
''',
            },
        ],
        css='''
.card { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 16px; padding: 20px; }
.domain { color: #6366f1; font-size: 12px; font-weight: bold; text-transform: uppercase; margin-bottom: 8px; }
.question { font-size: 18px; font-weight: 500; line-height: 1.5; margin-bottom: 16px; }
.options { font-size: 15px; color: #64748b; line-height: 1.8; }
.correct-answer { font-size: 17px; font-weight: bold; color: #16a34a; margin: 12px 0; padding: 8px; background: #f0fdf4; border-radius: 8px; }
.explanation { font-size: 14px; color: #475569; line-height: 1.6; margin-top: 12px; }
'''
    )

    deck = genanki.Deck(
        generate_deck_id(f'KCNA Practice Exam {quiz_num}'),
        f'KCNA::Practice Exam {quiz_num}'
    )

    for q in questions:
        options_parts = []
        for opt in q.get('options', []):
            if isinstance(opt, dict):
                options_parts.append(f'• {opt.get("text", "")}')
            else:
                options_parts.append(f'• {opt}')
        options_html = '<br>'.join(options_parts)
        correct = ', '.join(q.get('correct', ['Unknown']))

        # Build explanation: overall + per-option explanations
        explanation_parts = []
        overall = q.get('overallExplanation', '')
        if overall:
            explanation_parts.append(overall)
        for opt in q.get('options', []):
            if isinstance(opt, dict) and opt.get('explanation'):
                opt_text = opt.get('text', '')[:60]
                explanation_parts.append(f'<b>{opt_text}:</b> {opt["explanation"]}')
        explanation = '<br><br>'.join(explanation_parts)

        note = genanki.Note(
            model=model,
            fields=[
                q.get('question', ''),
                correct,
                options_html,
                explanation,
                q.get('domain', 'KCNA'),
            ]
        )
        deck.add_note(note)

    genanki.Package(deck).write_to_file(output_path)
    return len(questions)


def create_anki_text(quiz_data, output_path):
    """Create tab-separated text file for Anki import."""
    quiz_num = quiz_data['quiz']
    questions = quiz_data['questions']

    lines = []
    for q in questions:
        question = q.get('question', '').replace('\t', ' ').replace('\n', '<br>')
        correct = ', '.join(q.get('correct', ['Unknown'])).replace('\t', ' ')
        options_parts = []
        for opt in q.get('options', []):
            if isinstance(opt, dict):
                options_parts.append(f'• {opt.get("text", "")}')
            else:
                options_parts.append(f'• {opt}')
        options = '<br>'.join(options_parts).replace('\t', ' ')

        # Build explanation: overall + per-option explanations
        explanation_parts = []
        overall = q.get('overallExplanation', '')
        if overall:
            explanation_parts.append(overall)
        for opt in q.get('options', []):
            if isinstance(opt, dict) and opt.get('explanation'):
                opt_text = opt.get('text', '')[:60]
                explanation_parts.append(f'<b>{opt_text}:</b> {opt["explanation"]}')
        explanation = '<br><br>'.join(explanation_parts).replace('\t', ' ').replace('\n', '<br>')
        domain = q.get('domain', 'KCNA').replace('\t', ' ')

        # Front: Domain + Question + Options
        front = f'<div style="color:#6366f1;font-size:12px;font-weight:bold">{domain}</div>'
        front += f'<div style="font-size:18px;margin:8px 0">{question}</div>'
        front += f'<div style="color:#64748b;font-size:14px">{options}</div>'

        # Back: Correct answer + Explanation
        back = f'<div style="color:#16a34a;font-weight:bold;font-size:17px">✅ {correct}</div>'
        back += f'<div style="color:#475569;font-size:14px;margin-top:8px">{explanation}</div>'

        lines.append(f'{front}\t{back}')

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    return len(questions)


def main():
    script_dir = Path(__file__).parent
    quiz_files = sorted(script_dir.glob('quiz_*.json'))

    if not quiz_files:
        print('No quiz JSON files found. Expected quiz_1.json, quiz_2.json, etc.')
        sys.exit(1)

    print(f'Found {len(quiz_files)} quiz files')

    all_questions = []
    for qf in quiz_files:
        with open(qf, 'r') as f:
            data = json.load(f)
        count = data.get("valid", data.get("total", len(data["questions"])))
        print(f'  Quiz {data["quiz"]}: {count} questions')
        all_questions.extend(data['questions'])

    if HAS_GENANKI:
        print('\nUsing genanki to create .apkg files...')

        # Individual quiz decks
        for qf in quiz_files:
            with open(qf, 'r') as f:
                data = json.load(f)
            output = script_dir / f'KCNA_Practice_Exam_{data["quiz"]}.apkg'
            count = create_anki_deck_genanki(data, str(output))
            print(f'  Created {output.name} ({count} cards)')

        # Combined deck
        combined_data = {
            'quiz': 'All',
            'questions': all_questions
        }
        output = script_dir / 'KCNA_All_Practice_Exams.apkg'
        count = create_anki_deck_genanki(combined_data, str(output))
        print(f'  Created {output.name} ({count} cards)')

    else:
        print('\ngenanki not installed. Creating tab-separated text files for Anki import...')
        print('  To install: pip install genanki')

        # Individual quiz text files
        for qf in quiz_files:
            with open(qf, 'r') as f:
                data = json.load(f)
            output = script_dir / f'KCNA_Practice_Exam_{data["quiz"]}.txt'
            count = create_anki_text(data, str(output))
            print(f'  Created {output.name} ({count} cards)')

        # Combined text file
        combined_data = {
            'quiz': 'All',
            'questions': all_questions
        }
        output = script_dir / 'KCNA_All_Practice_Exams.txt'
        count = create_anki_text(combined_data, str(output))
        print(f'  Created {output.name} ({count} cards)')

    print(f'\nTotal: {len(all_questions)} flashcards across {len(quiz_files)} quizzes')
    print('Done!')


if __name__ == '__main__':
    main()
