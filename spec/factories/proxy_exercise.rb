FactoryBot.define do
  factory :proxy_exercise, class: ProxyExercise do
    created_by_teacher
    token { 'dummytoken' }
    title { 'Dummy' }
  end

end
