package org.nsvformat

import java.nio.file.{Files, Paths}

object Roundtrip:
  def main(args: Array[String]): Unit =
    val dir = Paths.get(args(0))
    var passed = 0; var failed = 0
    val fails = collection.mutable.ArrayBuffer[String]()
    Files.list(dir).sorted.forEach: p =>
      if p.toString.endsWith(".nsv") then
        val orig = Files.readString(p)
        if Nsv.encode(Nsv.decode(orig)) == orig then passed += 1
        else { failed += 1; fails += p.getFileName.toString }
    println(s"  $passed/${passed + failed} passed")
    fails.foreach(f => println(s"  $f"))
    if failed > 0 then System.exit(1)
