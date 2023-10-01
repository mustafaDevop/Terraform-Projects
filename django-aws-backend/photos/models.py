from django.db import models

# Create your models here.
class Photo(models.Model):
    title = models.CharField("Title", max_length=255)
    image = models.ImageField("Image", upload_to="photos/")