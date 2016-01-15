require 'spec_helper'
require 'command'
require 'zendesk_apps_tools/server'

describe ZendeskAppsTools::Command do
  let(:default_options) { { path: './', config: './settings.yml', port: 4567, dev: true } }

  before do
    @command = ZendeskAppsTools::Command.new
    @command.instance_variable_set(:@options, default_options)
    allow(ZendeskAppsTools::Server).to receive(:run!).and_return('run server')
  end

  describe '#server' do
    context "default options" do

      it 'errors when no arguments are given' do
        expect{ @command.server() }.to raise_error(Errno::ENOENT)
      end

      it 'runs when a path argument is given' do
        expect( @command.server('spec/app') ).to be(ZendeskAppsTools::Server)
      end

      it 'runs with multiple paths' do
        expect( @command.server('spec/app', 'spec/app') ).to be(ZendeskAppsTools::Server)
      end
    end

    context "-p option" do
      let(:default_options) { super().merge({ path: 'spec/app'}) }
      it 'runs when a -p argument is given' do
        expect( @command.server() ).to be(ZendeskAppsTools::Server)
      end

      it 'errors when a -p argument is given and a path' do
        expect{ @command.server('spec/app') }.to raise_error
      end
    end

    context "-c option" do
      let(:default_options) { super().merge({ path: 'spec/app', config: 'spec/app/settings.yml'}) }
      it 'runs when a -c argument is given' do
        expect( @command.server() ).to be(ZendeskAppsTools::Server)
      end

      it 'errors when a -c argument is given and a path' do
        expect{ @command.server('spec/app') }.to raise_error
      end
    end

    context "--app_id option" do
      let(:default_options) { super().merge({ path: 'spec/app', app_id: 12}) }
      it 'runs when a --app_id argument is given' do
        expect( @command.options[:app_id] ).to be( 12 )
        expect( @command.server() ).to be(ZendeskAppsTools::Server)
      end

      it 'errors when a --app_id argument is given and a path' do
        expect{ @command.server('spec/app') }.to raise_error
      end
    end
  end
end
