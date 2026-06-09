package org.nsvformat

import java.nio.file.{Files, Paths}

object Coercion:
  def main(args: Array[String]): Unit =
    val mode = args(0)
    val indir = Paths.get(args(1))
    val outdir = Paths.get(args(2))

    Files.list(indir).filter(_.toString.endsWith(".nsv")).sorted.forEach { p =>
      val out = outdir.resolve(p.getFileName.toString)
      if mode == "batch" then
        Files.writeString(out, Nsv.encode(Nsv.decode(Files.readString(p))))
      else
        val in = new java.io.BufferedReader(new java.io.FileReader(p.toFile))
        val bw = new java.io.BufferedWriter(new java.io.FileWriter(out.toFile))
        val reader = new Reader(in)
        val writer = new Writer(bw)
        while reader.hasNext do writer.writeRow(reader.next())
        bw.close()
        in.close()
    }
