---
layout: "main.liquid"
page_title: Home
---

# {{ blog_title }}

{% for collection in index.data %}
  <div class="collection">
    <h1>{{ collection.attributes.name }}</h1>
    {% for article in collection.attributes.articles.data %}
    <article>
      <h2>{{ article.attributes.title }}</h2>

      by {{ article.attributes.author }} on {{ article.attributes.publishedAt }}

      {{ article.attributes.body }}

      last updated at {{ article.attributes.updatedAt }}

      {% for tag in article.attributes.tags.data %}
        [{{ tag.attributes.name }}](/tags/{{ tag.attributes.slug }})
      {% endfor %}
    </article>
    {% endfor %}
  </div>
{% endfor %}
