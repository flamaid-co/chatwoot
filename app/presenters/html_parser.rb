class HtmlParser
  def self.parse_reply(raw_body)
    new(raw_body).filtered_text
  end

  attr_reader :raw_body

  def initialize(raw_body)
    @raw_body = raw_body
  end

  def document
    @document ||= Nokogiri::HTML(raw_body)
  end

  def filter_replies!
    document.xpath('//blockquote').each { |n| n.replace('&gt; ') }
  end

  def filtered_html
    @filtered_html ||= begin
      filter_replies!
      document.inner_html
    end
  end

  def filtered_text
    @filtered_text ||= Html2Text.convert(filtered_html)
  rescue StandardError, SystemStackError => e
    # Some emails contain pathological / deeply-nested HTML that makes
    # html2text recurse until it raises SystemStackError ("stack level too
    # deep"). SystemStackError is NOT a StandardError, so it escapes the
    # per-mail `rescue StandardError` in Inboxes::FetchImapEmailsJob and
    # crashes the entire IMAP fetch — silently blocking ALL email ingestion
    # for the channel (a single "poison" email halts the inbox).
    # Degrade gracefully to a plain-text extraction instead.
    Rails.logger.warn("HtmlParser: Html2Text.convert failed (#{e.class}); falling back to plain text")
    @filtered_text = begin
      Nokogiri::HTML(raw_body).text.to_s.strip
    rescue StandardError, SystemStackError
      raw_body.to_s
    end
  end
end
