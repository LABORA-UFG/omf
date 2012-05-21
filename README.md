# OMF

[![Build Status](https://secure.travis-ci.org/mytestbed/omf.png)](http://travis-ci.org/mytestbed/omf)

## Introduction

OMF is a framework for controlling, instrumenting, and managing experimental platforms (testbeds).

* Researchers use OMF to describe, instrument, and execute their experiments.

* Testbed providers use OMF to make their resources discoverable, control access to them, optimise their utilisation through virtualisation, and federation with other testbeds.

[More information](https://omf.mytestbed.net/projects/omf/wiki/Introduction)

## Official website

[http://www.mytestbed.net/](http://www.mytestbed.net/)

## Installation

OMF components are released as Ruby Gems.

To install OMF RC, simple type:

    gem install omf_rc

Common library omf\_common will be included automatically by RC.

To only install OMF Common library:

    gem install omf_common

## Extend OMF

We sincerely welcome all contributions to OMF. Simply fork our project via github, and send us pull requests whenever you are ready.

## Supported Ruby versions

We are building and testing against Ruby version 1.9.2 and 1.9.3, means we are dropping support for Ruby 1.8.

## Components

### Common

Common library shared among OMF applications

* PubSub communication, with default XMPP implementation, using Blather gem.
* OMF message class for authoring and parsing messages based on new OMF messaging protocol.
* RelaxNG schema for messaging protocol definition and validation.

### Resource Controller

* Resource proxy API for designing resource functionalities.
* Abstract resource provides common features required for all resources.

## OMF 6 design documentation

For full documentation regarding design of OMF version 6, please visit our [official documentation](http://omf.mytestbed.net/projects/omf/wiki/Architectural_Foundation)

## License & Copyright

Copyright (c) 2006-2012 National ICT Australia (NICTA), Australia

Copyright (c) 2004-2009 WINLAB, Rutgers University, USA

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
in the software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sub-license, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

* The above copyright notice and this permission notice shall be included in all copies or substantial portions of the software.

* The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and non-infringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
