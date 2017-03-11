require 'helper'
require 'flipper/registry'

RSpec.describe Flipper::Registry do
  subject { described_class.new(source) }

  let(:source) { {} }

  describe '#add' do
    it 'adds to source' do
      value = 'thing'
      subject.add(:admins, value)
      expect(source[:admins]).to eq(value)
    end

    it 'converts key to symbol' do
      value = 'thing'
      subject.add('admins', value)
      expect(source[:admins]).to eq(value)
    end

    it 'raises exception if key already registered' do
      subject.add(:admins, 'thing')

      expect do
        subject.add('admins', 'again')
      end.to raise_error(Flipper::Registry::DuplicateKey)
    end
  end

  describe '#get' do
    context 'key registered' do
      before do
        source[:admins] = 'thing'
      end

      it 'returns value' do
        expect(subject.get(:admins)).to eq('thing')
      end

      it 'returns value if given string key' do
        expect(subject.get('admins')).to eq('thing')
      end
    end

    context 'key not registered' do
      it 'raises key not found' do
        expect do
          subject.get(:admins)
        end.to raise_error(Flipper::Registry::KeyNotFound)
      end
    end
  end

  describe '#key?' do
    before do
      source[:admins] = 'admins'
    end

    it 'returns true if the key exists' do
      expect(subject.key?(:admins)).to eq true
    end

    it 'returns false if the key does not exists' do
      expect(subject.key?(:unknown_key)).to eq false
    end
  end

  describe '#each' do
    before do
      source[:admins] = 'admins'
      source[:devs] = 'devs'
    end

    it 'iterates source keys and values' do
      results = {}
      subject.each do |key, value|
        results[key] = value
      end
      expect(results).to eq(admins: 'admins',
                            devs: 'devs')
    end
  end

  describe '#keys' do
    before do
      source[:admins] = 'admins'
      source[:devs] = 'devs'
    end

    it 'returns the keys' do
      expect(subject.keys.map(&:to_s).sort).to eq(%w(admins devs))
    end

    it 'returns the keys as symbols' do
      subject.keys.each do |key|
        expect(key).to be_instance_of(Symbol)
      end
    end
  end

  describe '#values' do
    before do
      source[:admins] = 'admins'
      source[:devs] = 'devs'
    end

    it 'returns the values' do
      expect(subject.values.map(&:to_s).sort).to eq(%w(admins devs))
    end
  end

  describe 'enumeration' do
    before do
      source[:admins] = 'admins'
      source[:devs] = 'devs'
    end

    it 'works' do
      keys = []
      values = []

      subject.map do |key, value|
        keys << key
        values << value
      end

      expect(keys.map(&:to_s).sort).to eq(%w(admins devs))
      expect(values.sort).to eq(%w(admins devs))
    end
  end

  describe '#clear' do
    before do
      source[:admins] = 'admins'
    end

    it 'clears the source' do
      subject.clear
      expect(source).to be_empty
    end
  end

  describe '#fetch' do
    context 'key registered' do
      before do
        source[:admins] = 'admins'
      end

      it 'returns value' do
        expect(subject.fetch(:admins) {}).to eq('admins')
      end

      it 'returns value with string key' do
        expect(subject.fetch('admins') {}).to eq('admins')
      end
    end

    context 'key not registered' do
      it 'sets value to result of block' do
        subject.fetch(:admins) { 'admins' }
        expect(source[:admins]).to eq('admins')
      end
    end

    context 'key not registered and block not provided' do
      it 'raises error' do
        expect do
          subject.fetch(:admins)
        end.to raise_error(ArgumentError, "block is required")
      end
    end
  end
end
