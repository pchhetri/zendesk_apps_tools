require 'spec_helper'
require 'thor/actions'
require 'translate'

describe ZendeskAppsTools::Translate do
  describe '#to_yml' do
    it 'should convert i18n formatted json to translation yml' do
      root = 'spec/fixture/i18n_app_to_yml'
      target_yml = "#{root}/translations/en.yml"
      File.delete(target_yml) if File.exist?(target_yml)
      subject.setup_path(root)
      subject.to_yml

      expect(File.read(target_yml)).to eq(File.read("#{root}/translations/expected.yml"))
      File.delete(target_yml) if File.exist?(target_yml)
    end
  end

  describe '#to_json' do
    it 'should convert translation yml to i18n formatted json' do
      root = 'spec/fixture/i18n_app_to_json'
      target_json = "#{root}/translations/en.json"
      File.delete(target_json) if File.exist?(target_json)

      subject.setup_path(root)
      subject.to_json

      expect(File.read(target_json)).to eq(File.read("#{root}/translations/expected.json"))
      File.delete(target_json) if File.exist?(target_json)
    end
  end

  describe '#nest_translations_hash' do
    it 'removes package key prefix' do
      translations = { 'txt.apps.my_app.app.description' => 'Description' }

      result = { 'app' => { 'description' => 'Description' } }

      context = ZendeskAppsTools::Translate.new
      expect(context.nest_translations_hash(translations, 'txt.apps.my_app.')).to eq(result)
    end

    describe 'with a mix of nested and unnested keys' do
      it 'returns a mixed depth hash' do
        translations = {
          'app.description' => 'This app is awesome',
          'app.parameters.awesomeness.label' => 'Awesomeness level',
          'global.error.title'   => 'An error occurred',
          'global.error.message' => 'Please try the previous action again.',
          'global.loading'       => 'Waiting for ticket data to load...',
          'global.requesting'    => 'Requesting data from Magento...',
          'errormessage'         => 'General error' }

        result = {
          'app' => {
            'description' => 'This app is awesome',
            'parameters' => {
              'awesomeness' => { 'label' => 'Awesomeness level' } }
          },
          'global' => {
            'error' => {
              'title'   => 'An error occurred',
              'message' => 'Please try the previous action again.'
            },
            'loading'    => 'Waiting for ticket data to load...',
            'requesting' => 'Requesting data from Magento...'
          },
          'errormessage' => 'General error'
        }

        expect(subject.nest_translations_hash(translations, '')).to eq(result)
      end
    end
  end

  # This would be better as an integration test but it requires significant
  # refactoring of the cucumber setup and addition of vcr or something similar
  # This is happy day only
  describe '#update' do
    before :each do
      allow(subject).to receive(:write_json)
      allow(subject).to receive(:nest_translations_hash).once.and_return({})

      root = 'spec/fixture/i18n_app_update'
      target_json = "#{root}/translations/fr.json"
      org_json = "#{root}/translations/fr_expected.json"
      subject.setup_path(root)

      # Copy fr_expected.json to fr.json
      File.delete(target_json) if File.exist?(target_json)
      File.write(target_json, File.read(org_json))

      @test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/v2/locales/agent.json') do
            [200, {}, JSON.dump('locales' => [{ 'url' => 'https://support.zendesk.com/api/v2/rosetta/locales/fr.json',
                                                'locale' => 'fr' }])]
          end
          stub.get('/api/v2/rosetta/locales/fr.json?include=translations&packages=app_my_app') do
            [200, {}, JSON.dump('locale' => { 'translations' =>
                                                    { 'app.description' => 'my awesome app' } })]
          end
        end
      end
    end

    it 'fetches locales, translations and generates json files for each' do
      allow(subject).to receive(:ask).with('What is the package name for this app? (without app_)').and_return('my_app')

      expect(subject).to receive(:write_json).with("translations/fr.json", anything, anything)

      subject.update @test
    end

    context 'with an app package supplied as an option' do

      it 'performs the update without asking for input' do
        subject.options = { app_package: 'my_app' }

        expect(subject).not_to receive(:ask).with('What is the package name for this app? (without app_)')

        expect { subject.update @test }.to output(/Translations updated/).to_stdout
      end

    end

    describe 'when there is an existing translation file for a locale' do
      before(:each) do
        allow(subject).to receive(:write_json).and_call_original
        subject.options = { app_package: 'my_app' }
      end

      it 'prompts the user to manually resolve the file write conflict' do
        allow(subject.shell).to receive(:ask).and_return 'y'

        expect { subject.update @test }.to output(/conflict/).to_stdout
      end

      it 'overwrites the file if the force option is supplied' do
        subject.options[:force] = true

        expect { subject.update @test }.to output(/Translations updated/).to_stdout
      end

    end

  end

  describe "#pseudotranslate" do
    it 'generates a json file for the specified locale' do
      root = 'spec/fixture/i18n_app_pseudotranslate'
      target_json = "#{root}/translations/fr.json"
      File.delete(target_json) if File.exist?(target_json)

      subject.setup_path(root)
      subject.pseudotranslate

      expect(File.read(target_json)).to eq(File.read("#{root}/translations/expected.json"))
      File.delete(target_json) if File.exist?(target_json)
    end
  end
end
