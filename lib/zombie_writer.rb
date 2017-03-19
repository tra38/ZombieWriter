require "zombie_writer/version"
require "zombie_writer/redcarpet_configuration"
require 'classifier-reborn'
require 'kmeans-clusterer'

module ZombieWriter

  def self.citation_constructor(paragraph)
    if (paragraph[:sourceurl] && paragraph[:sourcetext])
      "---[#{paragraph[:sourcetext]}](#{paragraph[:sourceurl]})"
    elsif paragraph[:sourcetext]
      "---#{paragraph[:sourcetext]}"
    elsif paragraph[:sourceurl]
      "---[#{paragraph[:sourceurl]}](#{paragraph[:sourceurl]})"
    else
      ""
    end
  end

  def self.header(index, article_for_summarization)
    generated_title = ClassifierReborn::Summarizer.summary(article_for_summarization, 1)
    "## #{index} - #{generated_title}"
  end

  def self.formatted_article(header, final_article)
    "#{header}\n\n#{final_article}\n"
  end

  class MachineLearning
    attr_reader :lsi, :labels, :paragraph_data, :renderer, :plain_to_markdown

    def initialize
      @lsi = ClassifierReborn::LSI.new
      @labels = []
      @paragraph_data = Hash.new
      @plain_to_markdown = Hash.new
      @renderer = Redcarpet::Markdown.new(CustomStripDownRender)
    end

    def add_string(paragraph)
      content = paragraph[:content]

      stripped_down_content = renderer.render(content)

      plain_to_markdown[stripped_down_content] = content

      paragraph_data[content] = ZombieWriter.citation_constructor(paragraph)

      labels << stripped_down_content
      lsi.add_item(stripped_down_content)
    end

    def generate_articles
      number_of_articles = labels.length
      clusters = determine_number_of_clusters(number_of_articles)
      clusters = generate_clusters(clusters: clusters, runs: 10)
      clusters.map do |cluster|
        article_for_summarization = generate_article(cluster) do |point|
          point.label
        end

        final_article = generate_article(cluster) do |point|
          stripped_down_content = point.label
          content = plain_to_markdown[stripped_down_content]
          citation = paragraph_data[content]
          "#{content}#{citation}"
        end

        header = ZombieWriter.header(cluster.id.to_s, article_for_summarization)
        ZombieWriter.formatted_article(header, final_article)
      end
    end

    private
    def generate_clusters(clusters:, runs:)
      string_data = lsi.instance_variable_get(:"@items")
      data = labels.map do |string|
        string_data[string].lsi_norm.to_a
      end
      kmeans = KMeansClusterer.run clusters, data, labels: labels, runs: runs
      kmeans.clusters
    end

    def determine_number_of_clusters(number_of_articles)
      [1, ((number_of_articles/5).to_f).floor].max
    end

    def generate_article(cluster, &block)
      cluster.points.map do |point|
        yield(point)
      end.join("\n\n")
    end
  end

  class Randomization
    attr_reader :labels, :paragraph_data, :renderer

    def initialize
      @labels = []
      @paragraph_data = Hash.new
      @renderer = Redcarpet::Markdown.new(CustomStripDownRender)
    end

    def add_string(paragraph)
      content = paragraph[:content]

      paragraph_data[content] = ZombieWriter.citation_constructor(paragraph)

      labels << content
    end

    def generate_articles
      number_of_paragraphs = labels.length
      possible_paragraphs = labels.shuffle

      possible_paragraphs.each_slice(5).with_index.map do |cluster, index|
        article_for_summarization = generate_article(cluster) do |content|
          renderer.render(content)
        end

        final_article = generate_article(cluster) do |content|
          citation = paragraph_data[content]
          "#{content}#{citation}"
        end

        header = ZombieWriter.header(index, article_for_summarization)
        ZombieWriter.formatted_article(header, final_article)
      end
    end

    private
    def generate_article(cluster, &block)
      cluster.map do |content|
        yield(content)
      end.join("\n\n")
    end

  end


end
