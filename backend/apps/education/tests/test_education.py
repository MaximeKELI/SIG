import pytest

from education.models import QuizQuestion, UserBadge
from education.services import award_badges, weekly_leaderboard


@pytest.fixture
def quiz_questions(db):
    questions = []
    for i, diff in enumerate(['facile'] * 5):
        questions.append(QuizQuestion.objects.create(
            text=f'Question {i}?',
            difficulty=diff,
            choices=['A', 'B', 'C', 'D'],
            correct_index=0,
            explanation='Parce que.',
            points=5,
        ))
    return questions


@pytest.mark.django_db
def test_quiz_start(auth_client, quiz_questions):
    r = auth_client.post('/api/v1/education/quiz/start/', {
        'difficulty': 'facile', 'count': 3,
    }, format='json')
    assert r.status_code == 200
    assert 'session_id' in r.json()
    assert len(r.json()['questions']) == 3
    assert r.json()['timer_seconds'] == 20


@pytest.mark.django_db
def test_quiz_answer_and_finish(auth_client, quiz_questions, agent_user):
    start = auth_client.post('/api/v1/education/quiz/start/', {
        'difficulty': 'facile', 'count': 2,
    }, format='json')
    sid = start.json()['session_id']
    q = start.json()['questions'][0]
    r = auth_client.post(f'/api/v1/education/quiz/{sid}/answer/', {
        'question_id': q['id'], 'selected_index': 0,
    }, format='json')
    assert r.status_code == 200
    assert r.json()['correct'] is True
    finish = auth_client.post(f'/api/v1/education/quiz/{sid}/finish/', {}, format='json')
    assert finish.status_code == 200
    assert 'final_score' in finish.json()


@pytest.mark.django_db
def test_pedagogical_sheets_api(api_client, db):
    from education.models import PedagogicalSheet
    PedagogicalSheet.objects.create(
        title='Test', theme='nasa', content_fr='Contenu NASA', order=1,
    )
    r = api_client.get('/api/v1/education/sheets/')
    assert r.status_code == 200
    payload = r.json()
    row = (payload.get('results') or payload)[0]
    assert 'pdf_url' in row
    assert row['pdf_url'].startswith('/api/v1/education/sheets/')
    assert row['pdf_url'].endswith('/pdf/')


@pytest.mark.django_db
def test_pedagogical_sheet_pdf(api_client, db):
    from education.models import PedagogicalSheet
    s = PedagogicalSheet.objects.create(title='Fiche test', theme='nasa', content_fr='Aperçu', order=0)
    r = api_client.get(f'/api/v1/education/sheets/{s.pk}/pdf/')
    assert r.status_code == 200
    assert r.content[:4] == b'%PDF'
    assert 'inline' in (r.get('Content-Disposition') or '').lower()


@pytest.mark.django_db
def test_pedagogical_sheet_pdf_download_attachment(api_client, db):
    from education.models import PedagogicalSheet
    s = PedagogicalSheet.objects.create(title='Fiche DL', theme='types', content_fr='x', order=1)
    r = api_client.get(f'/api/v1/education/sheets/{s.pk}/pdf/?download=1')
    assert r.status_code == 200
    assert 'attachment' in (r.get('Content-Disposition') or '').lower()


@pytest.mark.django_db
def test_quiz_start_unique_question_ids(auth_client, db):
    from django.core.management import call_command
    call_command('seed_quiz_questions', '--force')
    r = auth_client.post('/api/v1/education/quiz/start/', {
        'difficulty': 'facile', 'count': 20,
    }, format='json')
    assert r.status_code == 200
    ids = [q['id'] for q in r.json()['questions']]
    assert len(ids) == len(set(ids))


@pytest.mark.django_db
def test_quiz_stats_api(api_client, db):
    from django.core.management import call_command
    call_command('seed_quiz_questions', '--force')
    r = api_client.get('/api/v1/education/quiz/stats/')
    assert r.status_code == 200
    data = r.json()
    assert data['by_level']['facile'] >= 100
    assert data['per_level_target'] == 100


@pytest.mark.django_db
def test_leaderboard_api(api_client):
    r = api_client.get('/api/v1/education/quiz/leaderboard/')
    assert r.status_code == 200
    assert 'top_10' in r.json()


@pytest.mark.django_db
def test_award_apprenti_badge(agent_user, db):
    from education.models import QuizSession
    QuizSession.objects.create(
        user=agent_user, difficulty='facile',
        score=25, questions_answered=5, completed=True,
    )
    badges = award_badges(agent_user)
    assert 'apprenti' in badges or UserBadge.objects.filter(user=agent_user, badge='apprenti').exists()


@pytest.mark.django_db
def test_weekly_leaderboard_empty():
    assert weekly_leaderboard() == []


@pytest.mark.django_db
def test_quiz_certificate_requires_auth(api_client, quiz_questions, agent_user):
    from education.models import QuizSession
    session = QuizSession.objects.create(
        user=agent_user,
        difficulty='facile',
        score=25,
        questions_answered=5,
        completed=True,
    )
    r = api_client.get(f'/api/v1/education/quiz/{session.pk}/certificate/')
    assert r.status_code in (401, 403)


@pytest.mark.django_db
def test_quiz_certificate_pdf_authenticated(auth_client, quiz_questions, agent_user):
    from education.models import QuizSession
    session = QuizSession.objects.create(
        user=agent_user,
        difficulty='facile',
        score=25,
        questions_answered=5,
        completed=True,
    )
    r = auth_client.get(f'/api/v1/education/quiz/{session.pk}/certificate/')
    assert r.status_code == 200
    assert r['Content-Type'] == 'application/pdf'
    assert r.content[:4] == b'%PDF'
    assert len(r.content) > 2000
    assert 'certificat-quiz' in (r.get('Content-Disposition') or '')


@pytest.mark.django_db
def test_build_certificate_bytes_premium_layout(agent_user, db):
    from education.certificate_pdf import build_quiz_certificate_bytes
    from education.models import QuizSession
    session = QuizSession.objects.create(
        user=agent_user,
        difficulty='moyen',
        score=18,
        questions_answered=10,
        completed=True,
        exam_mode=True,
    )
    pdf = build_quiz_certificate_bytes(session, agent_user)
    assert pdf[:4] == b'%PDF'
    assert len(pdf) > 8000  # diplôme cérémonial plus dense
