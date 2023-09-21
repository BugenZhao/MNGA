use std::env;

fn open(path: &str, flush: bool) -> sled::Db {
    sled::Config::new()
        .path(path)
        .flush_every_ms(flush.then_some(1000))
        .cache_capacity(50 * 1024 * 1024)
        .open()
        .expect("cannot open or create cache db")
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        println!(
            "usage: {} <input> <output>",
            args.first().map_or("repair", |a| a.as_str())
        );
        return;
    }

    let old = open(&args[1], false);
    let new = open(&args[2], true);

    println!("old len: {}", old.len());
    let data = old.export();

    new.import(data);
    new.flush().unwrap();
    println!("new len: {}", new.len());
}
