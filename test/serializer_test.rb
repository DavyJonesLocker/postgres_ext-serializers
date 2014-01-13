require 'test_helper'

describe 'ArraySerializer patch' do
  let(:controller) { NotesController.new }
  let(:relation)   { Note.all }
  let(:json_data)  { ActiveModel::Serializer.build_json(controller, relation, {}).to_json }

  before do
    note_1 = Note.create name: 'test', content: 'dummy content'
    note_2 = Note.create name: 'test 2', content: 'dummy content'

    tag    = Tag.create name: 'tag 1', note_id: note_1.id
    @json_expected = "{\"tags\":[{\"id\":#{tag.id},\"name\":\"tag 1\"}],\"notes\":[{\"id\":#{note_1.id},\"content\":\"dummy content\",\"name\":\"test\",\"tag_ids\":[#{tag.id}]},{\"id\":#{note_2.id},\"content\":\"dummy content\",\"name\":\"test 2\",\"tag_ids\":[]}]}"
  end

  it 'generates the proper json output for the serializer' do
    json_data.must_equal @json_expected
  end

  it 'does not instantiate ruby objects for relations' do
    relation.stubs(:to_a).returns([])

    json_data
    assert_received(relation, :to_a) { |expect| expect.never}
  end
end
