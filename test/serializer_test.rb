require 'test_helper'


describe 'ArraySerializer patch' do
  let(:json_data)  { ActiveModel::Serializer.build_json(controller, relation, {}).to_json }

  context 'computed value methods' do
    let(:relation)   { Person.all }
    let(:controller) { PeopleController.new }
    let(:person)     { Person.create first_name: 'Test', last_name: 'User' }

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
end
