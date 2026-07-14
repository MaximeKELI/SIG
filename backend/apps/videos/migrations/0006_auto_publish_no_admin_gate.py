from django.db import migrations, models


def publish_pending_videos(apps, schema_editor):
    VideoPost = apps.get_model('videos', 'VideoPost')
    VideoPost.objects.filter(status='pending').update(status='published')


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('videos', '0005_videopost_tags_storypost'),
    ]

    operations = [
        migrations.AlterField(
            model_name='videopost',
            name='status',
            field=models.CharField(
                choices=[
                    ('pending', 'En attente'),
                    ('published', 'Publié'),
                    ('rejected', 'Refusé'),
                ],
                db_index=True,
                default='published',
                max_length=12,
            ),
        ),
        migrations.RunPython(publish_pending_videos, noop_reverse),
    ]
