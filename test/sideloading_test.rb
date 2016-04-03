
describe 'ArraySerializer patch' do
  let(:json_data)  { ActiveModel::Serializer.build_json(controller, relation, options).to_json }
  let(:options)    { }

  context 'no where clause on root relation' do
    let(:relation)   { Note.all }
    let(:controller) { NotesController.new }

    before do
      note_1 = Note.create name: 'test', content: 'dummy content'
      note_2 = Note.create name: 'test 2', content: 'dummy content'

      tag    = Tag.create name: 'tag 1', note_id: note_1.id
      Tag.create name: 'tag 2'
      @json_expected = "{\"notes\":[{\"id\":#{note_1.id},\"content\":\"dummy content\",\"name\":\"test\",\"tag_ids\":[#{tag.id}]}, \n {\"id\":#{note_2.id},\"content\":\"dummy content\",\"name\":\"test 2\",\"tag_ids\":[]}],\"tags\":[{\"id\":#{tag.id},\"name\":\"tag 1\",\"note_id\":#{note_1.id}}]}"
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
      @json_expected = "{\"notes\":[{\"id\":#{note_1.id},\"content\":\"dummy content\",\"name\":\"test\",\"tag_ids\":[#{tag.id}]}],\"tags\":[{\"id\":#{tag.id},\"name\":\"tag 1\",\"note_id\":#{note_1.id}}]}"
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

  context 'root relation has belongs_to association' do
    let(:relation)   { Tag.all }
    let(:controller) { TagsController.new }
    let(:options)    { { each_serializer: TagWithNoteSerializer } }

    before do
      note = Note.create content: 'Test', name: 'Title'
      tag = Tag.create name: 'My tag', note: note
      @json_expected = "{\"tags\":[{\"id\":#{tag.id},\"name\":\"My tag\",\"note_id\":#{note.id}}],\"notes\":[{\"id\":#{note.id},\"content\":\"Test\",\"name\":\"Title\",\"tag_ids\":[#{tag.id}]}]}"
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

  context 'relation has multiple associates to the same table' do
    let(:relation)   { User.order(:id) }
    let(:controller) { UsersController.new }

    before do
      reviewer = User.create name: 'Peter'
      user = User.create name: 'John'
      offer = Offer.create created_by: user, reviewed_by: reviewer
      @json_expected = "{\"users\":[{\"id\":#{reviewer.id},\"name\":\"Peter\",\"offer_ids\":[],\"reviewed_offer_ids\":[#{offer.id}]}, \n {\"id\":#{user.id},\"name\":\"John\",\"offer_ids\":[#{offer.id}],\"reviewed_offer_ids\":[]}],\"offers\":[{\"id\":#{offer.id}}],\"reviewed_offers\":[{\"id\":#{offer.id}}]}"
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

  context 'empty data should return empty array not null' do
    let(:relation)   { Tag.all }
    let(:controller) { TagsController.new }
    let(:options)    { { each_serializer: TagWithNoteSerializer } }

    before do
      @json_expected = "{\"tags\":[],\"notes\":[]}"
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

  context 'nested filtering support' do
    let(:relation)   { TagWithNote.where(notes: { name: 'Title' }) }
    let(:controller) { TagsController.new }

    before do
      note = Note.create content: 'Test', name: 'Title'
      tag = Tag.create name: 'My tag', note: note
      @json_expected = "{\"tags\":[{\"id\":#{tag.id},\"name\":\"My tag\",\"note_id\":#{note.id}}],\"notes\":[{\"id\":#{note.id},\"content\":\"Test\",\"name\":\"Title\",\"tag_ids\":[#{tag.id}]}]}"
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

  context 'support for include_[attrbute]' do
    let(:relation)   { User.all }
    let(:controller) { UsersController.new }
    let(:options)    { { each_serializer: UserSerializer } }
    before           { @user = User.create name: 'John', mobile: "51111111" }

    it 'generates json for serializer when include_[attribute]? is true' do
      address = Address.create district_name: "mumbai", user_id: @user.id
      json_expected = "{\"users\":[{\"id\":#{@user.id},\"name\":\"John\",\"mobile\":\"51111111\",\"offer_ids\":[],\"reviewed_offer_ids\":[]}],\"offers\":[],\"reviewed_offers\":[],\"addresses\":[{\"id\":#{address.id},\"district_name\":\"mumbai\"}]}"

      controller.stubs(:current_user).returns({ permission_id: 1 })
      json_data.must_equal json_expected
    end

    it 'generates json for serializer when include_[attribute]? is false' do
      json_output = "{\"users\":[{\"id\":#{@user.id},\"name\":\"John\",\"offer_ids\":[],\"reviewed_offer_ids\":[]}],\"offers\":[],\"reviewed_offers\":[]}"
      json_data.must_equal json_output
    end
  end

  context 'respects order in default scope of has_many association' do
    let(:relation)   { Note.all }
    let(:controller) { NotesController.new }
    let(:options)    { { each_serializer: SortedTagsNoteSerializer } }

    before do
      note = Note.create name: 'test', content: 'dummy content'

      tag2 = Tag.create name: 'tag 2', note_id: note.id
      tag1 = Tag.create name: 'tag 1', note_id: note.id
      tag3 = Tag.create name: 'tag 3', note_id: note.id
      @json_expected = "{\"notes\":[{\"id\":#{note.id},\"sorted_tag_ids\":[#{tag1.id},#{tag2.id},#{tag3.id}]}],\"sorted_tags\":[{\"id\":#{tag1.id},\"name\":\"tag 1\"}, \n {\"id\":#{tag2.id},\"name\":\"tag 2\"}, \n {\"id\":#{tag3.id},\"name\":\"tag 3\"}]}"
    end

    it 'generates json output with correctly sorted tag ids and tags' do
      json_data.must_equal @json_expected
    end
  end

  context 'respects order in custom scope of has_many association' do
    let(:relation)   { Note.all }
    let(:controller) { NotesController.new }
    let(:options)    { { each_serializer: CustomSortedTagsNoteSerializer } }

    before do
      note = Note.create name: 'test', content: 'dummy content'

      tag2 = Tag.create name: 'tag 2', note_id: note.id
      tag1 = Tag.create name: 'tag 1', note_id: note.id
      tag3 = Tag.create name: 'tag 3', note_id: note.id
      @json_expected = "{\"notes\":[{\"id\":#{note.id},\"custom_sorted_tag_ids\":[#{tag1.id},#{tag2.id},#{tag3.id}]}],\"custom_sorted_tags\":[{\"id\":#{tag1.id},\"name\":\"tag 1\"}, \n {\"id\":#{tag2.id},\"name\":\"tag 2\"}, \n {\"id\":#{tag3.id},\"name\":\"tag 3\"}]}"
    end

    it 'generates json output with correctly sorted tag ids and tags' do
      json_data.must_equal @json_expected
    end
  end
end
