Pod::Spec.new do |s|
	s.name = 'BMKDTree'
	s.version = '0.0.1'
	s.homepage = 'https://github.com/bm-w/BMKDTree'
	s.summary = 'An Objective-C implementation of a k-D tree with arbitrary objects'
	s.author = {
		'Bastiaan Marinus van de Weerd' => 'bastiaan@bm-w.eu'
	}
	s.source = {
		:git => 'https://github.com/bm-w/BMKDTree.git'
	}
	s.source_files = 'Classes/BMKDTree.{h,m}'
end
