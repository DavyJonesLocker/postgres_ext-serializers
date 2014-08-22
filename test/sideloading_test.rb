
describe 'ArraySerializer patch' do
  let(:json_data)  { ActiveModel::Serializer.build_json(controller, relation, {}).to_json }

  context 'no where clause on root relation' do
    let(:relation)   { Note.all }
    let(:controller) { NotesController.new }

    before do
      note_1 = Note.create name: 'test', content: 'dummy content'
      note_2 = Note.create name: 'test 2', content: 'dummy content'

      tag    = Tag.create name: 'tag 1', note_id: note_1.id
      Tag.create name: 'tag 2'
      @json_expected = "{\"tags\":[{\"id\":#{tag.id},\"name\":\"tag 1\",\"note_id\":#{note_1.id}}],\"notes\":[{\"id\":#{note_1.id},\"content\":\"dummy content\",\"name\":\"test\",\"tag_ids\":[#{tag.id}]},{\"id\":#{note_2.id},\"content\":\"dummy content\",\"name\":\"test 2\",\"tag_ids\":[]}]}"
    end

    it 'generates the proper json output for the serializer' do
      json_data.must_equal @json_expected
    end

    it 'does not instantiate ruby objects for relations' do
      relation.stub(:to_a,
                    -> { raise Exception.new('#to_a should never be called') }) do
        json_data
      end
    end
  end

  context 'where clause on root relation' do
    let(:relation)   { Note.where(name: 'test') }
    let(:controller) { NotesController.new }

    before do
      note_1 = Note.create name: 'test', content: 'dummy content'
      note_2 = Note.create name: 'test 2', content: 'dummy content'

      tag    = Tag.create name: 'tag 1', note_id: note_1.id
      Tag.create name: 'tag 2', note_id: note_2.id
      @json_expected = "{\"tags\":[{\"id\":#{tag.id},\"name\":\"tag 1\",\"note_id\":#{note_1.id}}],\"notes\":[{\"id\":#{note_1.id},\"content\":\"dummy content\",\"name\":\"test\",\"tag_ids\":[#{tag.id}]}]}"
    end

    it 'generates the proper json output for the serializer' do
      json_data.must_equal @json_expected
    end

    it 'does not instantiate ruby objects for relations' do
      relation.stub(:to_a,
                    -> { raise Exception.new('#to_a should never be called') }) do
        json_data
      end
    end
  end
end
