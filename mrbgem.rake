MRuby::Gem::Specification.new('mruby-finalize') do |spec|
  spec.license = 'MIT'
  spec.author  = 'Rob Fors'
  spec.version = '0.0.0'
  spec.summary = 'assign non-preemptive finalizers to most objects'

  spec.rbfiles = Dir.glob("#{dir}/mrblib/**/*.rb")
  spec.cxx.flags << "-std=c++11"
  spec.objs = Dir.glob("#{dir}/src/**/*.cpp")
    .map { |f| objfile(f.relative_path_from(dir).pathmap("#{build_dir}/%X")) }

  spec.add_dependency('mruby-attribute', '~> 0', :github => 'robfors/mruby-attribute')

  spec.test_rbfiles = Dir.glob("#{dir}/test/**/*.rb")
  spec.test_objs = Dir.glob("#{dir}/test/**/*.cpp")
    .map { |f| objfile(f.relative_path_from(dir).pathmap("#{build_dir}/%X")) }

  spec.add_test_dependency('mruby-metaprog', core: 'mruby-metaprog')
  spec.add_test_dependency('mruby-method', core: 'mruby-method')
  spec.add_test_dependency('mruby-objectspace', core: 'mruby-objectspace')
end
