//
//  InitConf.swift
//  NGA
//
//  Created by Bugen Zhao on 7/4/21.
//

import Foundation

func initConf() {
  let configuration = Configuration.with { c in
    c.documentDirPath = FileManager.default.urls(for: .documentDirectory, in: . userDomainMask)[0].path
  }

  let _: ConfigureResponse = try! logicCall(.configure(.with {
    $0.config = configuration
  }))
}
