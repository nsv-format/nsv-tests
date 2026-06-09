package org.nsvformat

import java.nio.file.{Files, Paths}

object Roundtrip:
  def main(args: Array[String]): Unit =
    val dir = Paths.get(args(0))
    val failures = collection.mutable.ArrayBuffer[String]()
    var total = 0

    Files.list(dir).filter(_.toString.endsWith(".nsv")).sorted.forEach { p =>
      total += 1
      val orig = Files.readString(p)
      if Nsv.encode(Nsv.decode(orig)) != orig then failures += p.getFileName.toString
    }

    println(s"  ${total - failures.length}/$total passed")
    failures.foreach(f => println(s"  $f"))
    if (failures.nonEmpty) System.exit(1)
