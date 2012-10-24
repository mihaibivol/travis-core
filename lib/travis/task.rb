require 'faraday'
require 'core_ext/hash/compact'
require 'core_ext/hash/deep_symbolize_keys'
require 'active_support/core_ext/string'

module Travis
  class Task
    # autoload :Archive,      'travis/task/archive'
    # autoload :Github,       'travis/task/github'
    autoload :Campfire,     'travis/task/campfire'
    autoload :Email,        'travis/task/email'
    autoload :Flowdock,     'travis/task/flowdock'
    autoload :GithubStatus, 'travis/task/github_status'
    autoload :Hipchat,      'travis/task/hipchat'
    autoload :Irc,          'travis/task/irc'
    autoload :Pusher,       'travis/task/pusher'
    autoload :Webhook,      'travis/task/webhook'

    module Shared
      autoload :Template,   'travis/task/shared/template'
    end

    include Logging
    extend  Instrumentation, NewRelic, Exceptions::Handling, Async

    class << self
      extend Exceptions::Handling

      def run(type, *args)
        Travis::Async.run(self, :perform, { :queue => type, :use => run_local? ? :threaded : :sidekiq }, type, *args)
      end

      def run_local?
        Travis::Features.feature_inactive?(:travis_tasks)
      end

      def perform(type, *args)
        const_get(type.to_s.camelize).new(*args).run
      end
      rescues :perform, :from => Exception
    end

    attr_reader :payload, :params

    def initialize(payload, params)
      @payload = payload.deep_symbolize_keys
      @params  = params.deep_symbolize_keys
    end

    def run
      process
    end
    rescues    :run, :from => Exception
    instrument :run
    new_relic  :run, :category => :task

    private

      def repository
        @repository ||= payload[:repository]
      end

      def job
        @job ||= payload[:job]
      end

      def build
        @build ||= payload[:build]
      end

      def request
        @request ||= payload[:request]
      end

      def commit
        @commit ||= payload[:commit]
      end

      def pull_request?
        build[:pull_request]
      end

      def http
        @http ||= Faraday.new(http_options) do |f|
          f.request :url_encoded
          f.adapter :net_http
        end
      end

      def http_options
        { :ssl => Travis.config.ssl.compact }
      end
  end
end
