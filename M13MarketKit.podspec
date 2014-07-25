Pod::Spec.new do |s|
  s.name         = "M13MarketKit"
  s.version      = "1.0.1"
  s.summary      = "M13MarketKit is a complete backend for handling in app purchases. It also includes a basic storefront as an example, or for use."

  s.description  = <<-DESC
                   M13MarketKit is a complete backend for handling in app purchases. It also includes a basic storefront as an example, or for use. Provides a complete, simple to use interface to the StoreKit framework.
                   DESC

  s.homepage     = "https://github.com/Marxon13/M13MarketKit"
  s.license      = {:type => 'MIT',
                    :text => <<-LICENSE
 Copyright (c) 2014 Brandon McQuilkin

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    LICENSE
 }

  s.author             = { "Brandon McQuilkin" => "marxon13@yahoo.com" }

  s.platform     = :ios, '8.0'

  s.source = { :git => "https://github.com/Marxon13/M13MarketKit.git", :tag => "v1.0.1"}

  s.source_files  = 'M13MarketKit/*'

  s.frameworks = 'Foundation', 'StoreKit', 'UIKit'

  s.requires_arc = true
  
end
