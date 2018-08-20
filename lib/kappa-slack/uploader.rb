require 'mechanize'
require 'httpclient'
require 'httpclient/webagent-cookie'
require 'json'
require 'fileutils'
require 'digest/sha1'

module KappaSlack
  class Uploader
    def initialize(
        slack_team_name:,
        slack_email:,
        slack_password:,
        skip_bttv_emotes:,
        skip_one_letter_emotes:,
        subscriber_emotes_from_channel:)
      @slack_team_name = slack_team_name
      @slack_email = slack_email
      @slack_password = slack_password
      @skip_bttv_emotes = skip_bttv_emotes
      @skip_one_letter_emotes = skip_one_letter_emotes
      @subscriber_emotes_from_channel = subscriber_emotes_from_channel
    end

    def upload
      visit('/') do |login_page|
        login_page.form_with(:id => 'signin_form') do |form|
          form.email = slack_email
          form.password = slack_password
        end.submit

        visit('/admin/emoji') do |emoji_page|
          uploaded_page = emoji_page
          tmp_dir_path = File.join(APP_ROOT, 'tmp')
          FileUtils.mkdir_p(tmp_dir_path)

          emotes.each do |emote|
            existing_emote = uploaded_page.search(".emoji_row:contains(':#{emote[:name]}:')")
            next if existing_emote.present?
            file_path = File.join(tmp_dir_path, Digest::SHA1.hexdigest(emote[:name]))

            File.open(file_path, 'w') do |file|
              http.get_content(emote[:url]) do |chunk|
                file.write(chunk)
              end
            end

            next if File.size(file_path) > 64 * 1024
            KappaSlack.logger.info "Uploading #{emote[:name]}"

            uploaded_page = uploaded_page.form_with(:id => 'addemoji') do |form|
              form.field_with(:name => 'name').value = emote[:name]
              form.file_upload_with(:name => 'img').file_name = file_path
            end.submit
          end

          FileUtils.rm_rf(tmp_dir_path)
        end
      end
    end

    private

    attr_reader :slack_team_name, :slack_email, :slack_password

    def skip_bttv_emotes?
      @skip_bttv_emotes
    end

    def skip_one_letter_emotes?
      @skip_one_letter_emotes
    end

    def subscriber_emotes_from_channel
      @subscriber_emotes_from_channel
    end

    def browser
      @browser ||= Mechanize.new
    end

    def http
      @http ||= HTTPClient.new
    end

    def visit(path, &block)
      browser.get(URI.join("https://#{slack_team_name}.slack.com", path), &block)
    end

    def bttv_emotes
      url_template = "https:#{response['urlTemplate'].gsub('{{image}}', '1x')}"
      if subscriber_emotes_from_channel.to_s.empty?
        KappaSlack.logger.info "Get BTTV emotes"
        response = JSON.parse(http.get_content('https://api.betterttv.net/2/emotes'))
        response['emotes'].map do |emote|
          {
              name: emote['code'].parameterize,
              url: url_template.gsub('{{id}}', emote['id'])
          }
        end
      else
        KappaSlack.logger.info "Get BTTV emotes for channel '#{subscriber_emotes_from_channel}'"
        response = JSON.parse(http.get_content("https://api.betterttv.net/2/channels/#{subscriber_emotes_from_channel}"))
        response['emotes'].map do |emote|
          {
              name: emote['code'].parameterize,
              url: url_template.gsub('{{id}}', emote['id'])
          }
        end
      end

    end

    def twitch_emotes
      url_template = 'https://static-cdn.jtvnw.net/emoticons/v1/{id}/1.0'
      if subscriber_emotes_from_channel.to_s.empty?
        KappaSlack.logger.info "Get emotes from twitch"
        response = JSON.parse(http.get_content('https://twitchemotes.com/api_cache/v3/global.json'))
        response.map do |name, emote|
          {
              name: name.parameterize,
              url: url_template.gsub('{id}', emote['id'].to_s)
          }
        end
      else
        channel = subscriber_emotes
        emotes = []
        channel.each do |channel_id, channelEntry|
          channelEntry['emotes'].each do |emote|
            emotes << emote
          end
        end

        emotes.map do |emote|
          {
              name: emote['code'].parameterize,
              url: url_template.gsub('{id}', emote['id'].to_s)
          }
        end
      end
    end

    def subscriber_emotes
      KappaSlack.logger.info "Get emotes for channel '#{subscriber_emotes_from_channel}'"
      response = JSON.parse(http.get_content('https://twitchemotes.com/api_cache/v3/subscriber.json'))
      response.select {|channel_id, channel| channel['channel_name'].casecmp(subscriber_emotes_from_channel) == 0}
    end

    def emotes
      all_emotes = twitch_emotes
      all_emotes += bttv_emotes unless skip_bttv_emotes?

      if skip_one_letter_emotes?
        all_emotes.select {|e| e[:name].length > 1}
      else
        all_emotes
      end
    end
  end
end
