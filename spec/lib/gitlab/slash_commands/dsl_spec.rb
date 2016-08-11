require 'spec_helper'

describe Gitlab::SlashCommands::Dsl do
  before :all do
    DummyClass = Struct.new(:project) do
      include Gitlab::SlashCommands::Dsl

      desc 'A command with no args'
      command :no_args, :none do
        "Hello World!"
      end

      desc 'A command returning a value'
      command :returning do
        return 42
      end

      params 'The first argument'
      command :one_arg, :once, :first do |arg1|
        arg1
      end

      desc do
        "A dynamic description for #{noteable.upcase}"
      end
      params 'The first argument', 'The second argument'
      command :two_args do |arg1, arg2|
        [arg1, arg2]
      end

      command :cc, noop: true

      condition do
        project == 'foo'
      end
      command :cond_action do |arg|
        arg
      end

      command :wildcard do |*args|
        args
      end
    end
  end

  describe '.command_definitions' do
    let(:base_expected) do
      [
        { name: :no_args, aliases: [:none], description: 'A command with no args', params: [], noop: false, cond_block: nil },
        { name: :returning, aliases: [], description: 'A command returning a value', params: [], noop: false, cond_block: nil },
        { name: :one_arg, aliases: [:once, :first], description: '', params: ['The first argument'], noop: false, cond_block: nil },
        { name: :two_args, aliases: [], description: '', params: ['The first argument', 'The second argument'], noop: false, cond_block: nil },
        { name: :cc, aliases: [], description: '', params: [], noop: true, cond_block: nil },
        { name: :wildcard, aliases: [], description: '', params: [], noop: false, cond_block: nil}
      ]
    end

    it 'returns an array with commands definitions' do
      expect(DummyClass.command_definitions).to match_array base_expected
    end

    context 'with options passed' do
      context 'when condition is met' do
        let(:expected) { base_expected << { name: :cond_action, aliases: [], description: '', params: [], noop: false, cond_block: a_kind_of(Proc) } }

        it 'returns an array with commands definitions' do
          expect(DummyClass.command_definitions(project: 'foo')).to match_array expected
        end
      end

      context 'when condition is not met' do
        it 'returns an array with commands definitions without actions that did not met conditions' do
          expect(DummyClass.command_definitions(project: 'bar')).to match_array base_expected
        end
      end

      context 'when description can be generated dynamically' do
        it 'returns an array with commands definitions with dynamic descriptions' do
          base_expected[3][:description] = 'A dynamic description for MERGE REQUEST'

          expect(DummyClass.command_definitions(noteable: 'merge request')).to match_array base_expected
        end
      end
    end
  end

  describe '.command_names' do
    let(:base_expected) do
      [
        :no_args, :none, :returning, :one_arg,
        :once, :first, :two_args, :wildcard
      ]
    end

    it 'returns an array with commands definitions' do
      expect(DummyClass.command_names).to eq base_expected
    end

    context 'with options passed' do
      context 'when condition is met' do
        let(:expected) { base_expected << :cond_action }

        it 'returns an array with commands definitions' do
          expect(DummyClass.command_names(project: 'foo')).to match_array expected
        end
      end

      context 'when condition is not met' do
        it 'returns an array with commands definitions without action that did not met conditions' do
          expect(DummyClass.command_names(project: 'bar')).to match_array base_expected
        end
      end
    end
  end

  let(:dummy) { DummyClass.new(nil) }

  describe 'command with no args' do
    context 'called with no args' do
      it 'succeeds' do
        expect(dummy.__send__(:no_args)).to eq 'Hello World!'
      end
    end
  end

  describe 'command with an explicit return' do
    context 'called with no args' do
      it 'succeeds' do
        expect(dummy.__send__(:returning)).to eq 42
      end
    end
  end

  describe 'command with one arg' do
    context 'called with one arg' do
      it 'succeeds' do
        expect(dummy.__send__(:one_arg, 42)).to eq 42
      end
    end
  end

  describe 'command with two args' do
    context 'called with two args' do
      it 'succeeds' do
        expect(dummy.__send__(:two_args, 42, 'foo')).to eq [42, 'foo']
      end
    end
  end

  describe 'noop command' do
    it 'is not meant to be called directly' do
      expect { dummy.__send__(:cc) }.to raise_error(NoMethodError)
    end
  end

  describe 'command with condition' do
    context 'when condition is not met' do
      it 'returns nil' do
        expect(dummy.__send__(:cond_action)).to be_nil
      end
    end

    context 'when condition is met' do
      let(:dummy) { DummyClass.new('foo') }

      it 'succeeds' do
        expect(dummy.__send__(:cond_action, 42)).to eq 42
      end
    end
  end

  describe 'command with wildcard' do
    context 'called with no args' do
      it 'succeeds' do
        expect(dummy.__send__(:wildcard)).to eq []
      end
    end

    context 'called with one arg' do
      it 'succeeds' do
        expect(dummy.__send__(:wildcard, 42)).to eq [42]
      end
    end

    context 'called with two args' do
      it 'succeeds' do
        expect(dummy.__send__(:wildcard, 42, 'foo')).to eq [42, 'foo']
      end
    end
  end
end
