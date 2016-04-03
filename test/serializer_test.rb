require 'test_helper'


describe 'ArraySerializer patch' do
  let(:json_data)  { ActiveModel::Serializer.build_json(controller, relation, options).to_json }

  context 'specify serializer' do
    let(:relation)   { Note.all }
    let(:controller) { NotesController.new }
    let(:options)    { { each_serializer: OtherNoteSerializer } }

    before do
      @note = Note.create content: 'Test', name: 'Title'
      @tag = Tag.create name: 'My tag', note: @note
    end

    it 'generates the proper json output' do
      json_expected = %{{"notes":[{"id":#{@note.id},"name":"Title","tag_ids":[#{@tag.id}]}],"tags":[{"id":#{@tag.id},"name":"My tag"}]}}
      json_data.must_equal json_expected
    end
  end

  context 'custom key and embed_key' do
    let(:relation)   { Note.all }
    let(:controller) { NotesController.new }
    let(:options)    { { each_serializer: CustomKeysNoteSerializer } }

    before do
      @note = Note.create content: 'Test', name: 'Title'
      @tag = Tag.create name: 'My tag', note: @note
    end

    it 'generates the proper json output' do
      json_expected = %{{"notes":[{"id":#{@note.id},"name":"Title","tag_names":["#{@tag.name}"]}],"tags":[{"id":#{@tag.id},"name":"My tag","tagged_note_id":#{@note.id}}]}}
      json_data.must_equal json_expected
    end
  end

  context 'computed value methods' do
    let(:relation)   { Person.all }
    let(:controller) { PeopleController.new }
    let(:person)     { Person.create first_name: 'Test', last_name: 'User' }
    let(:options)    { }

    it 'generates the proper json output for the serializer' do
      json_expected = %{{"people":[{"id":#{person.id},"full_name":"Test User","attendance_name":"User, Test"}]}}
      json_data.must_equal json_expected
    end

    it 'passes scope to the serializer method' do
      controller.stubs(:current_user).returns({ admin: true })

      json_expected = %{{"people":[{"id":#{person.id},"full_name":"Test User","attendance_name":"ADMIN User, Test"}]}}
      json_data.must_equal json_expected
    end
  end

  context 'merging bind values' do
    let(:relation)   { Note.joins(:popular_tags).where(name: 'Title') }
    let(:controller) { NotesController.new }
    let(:options)    { }

    before do
      @note = Note.create content: 'Test', name: 'Title'
      @tag = Tag.create name: 'My tag', note: @note, popular: true
    end

    it 'generates the proper json output' do
      json_expected = %{{"notes":[{"id":#{@note.id},"content":"Test","name":"Title","tag_ids":[#{@tag.id}]}],"tags":[{"id":#{@tag.id},"name":"My tag","note_id":#{@note.id}}]}}
      json_data.must_equal json_expected
    end
  end
end
