// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}



#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: "libertinus serif",
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: "libertinus serif",
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)
  if title != none {
    align(center)[#block(inset: 2em)[
      #set par(leading: heading-line-height)
      #if (heading-family != none or heading-weight != "bold" or heading-style != "normal"
           or heading-color != black) {
        set text(font: heading-family, weight: heading-weight, style: heading-style, fill: heading-color)
        text(size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(size: subtitle-size)[#subtitle]
        }
      } else {
        text(weight: "bold", size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(weight: "bold", size: subtitle-size)[#subtitle]
        }
      }
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/ctheorems:1.1.3": *
#show: thmrules
#let definition = thmbox("definition", "Definition")
#let example = thmbox("example", "Example")
#let lemma = thmbox("lemma", "Lemma")
#let theorem = thmbox("theorem", "Theorem")
#let proposition = thmbox("proposition", "Proposition")
#let corollary = thmbox("corollary", "Corollary")
#let exercise = thmbox("exercise", "Exercise")

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

#show: doc => article(
  title: [Lecture 1. Introduction],
  date: [2026-03-09],
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)

#block[
]
This post largely follows Chapter 1 of @Hong2026, reorganized and condensed with my own commentary. All credit for the original material goes to @Hong2026; any errors in exposition are mine. I highly recommend reading the original.

= Notations
<notations>
- $overline(k)$: a separable closure of a field $k$.
- $"Gal"_k$: absolute Galois group of a field $k$.

= Arithmetic perspective
<arithmetic-perspective>
In number theory, one of the main character is $ell$-adic Galois representations.

#definition("$ell$-adic representation")[
Let $Gamma$ be a profinite group. An $ell$-adic representation#footnote[There are various different definitions of $ell$-adic representation, e.g., using $overline(upright(bold(Q))_ell)$ in place of $upright(bold(Q))_ell$ (and assuming some properties).] is a continuous group homomorphism $ rho : Gamma arrow.r "GL"_n (upright(bold(Q))_ell) . $

] <def-l-adic-rep>
#example("$ell$-adic representations")[
~

+ For an abelian variety $A$ over a field $k$, the rational Tate module $V_ell (A) colon.eq upright(bold(Q))_ell times.circle_(upright(bold(Z))_ell) T_ell (A)$ is an $ell$-adic representation of $"Gal"_k$. Here, the (integral) Tate module $T_ell (A)$ is a $upright(bold(Z))_ell ["Gal"_k]$-module \$\$ T\_{\\ell}(A) \\coloneqq \\varprojlim\_{n} A\[\\ell^{n}\](\\overline{k}). \$\$

+ For a proper scheme $X$ over a field $k$, the étale cohomology $H_(upright(é t))^n (X_(overline(k)) \, upright(bold(Q))_ell)$ is an $ell$-adic representation of $"Gal"_k$.

] <exm-l-adic-reps>
#block[
#emph[Remark];. In fact, for an abelian variety $A$ over a field $k$, we obtain $ T_ell (A) = H_(upright(é t))^1 (A_(overline(k)) \, upright(bold(Z))_ell)^or $ as $upright(bold(Z))_ell ["Gal"_k]$-modules.

]
From now on, we focus on local Galois representations. Note that for a global Galois representation $rho : "Gal"_(upright(bold(Q))) arrow.r "GL" (V)$, we can induce a local Galois representation $rho_p : "Gal"_(upright(bold(Q))_p) arrow.r "GL" (V)$ by composing the restriction map $"Gal"_(upright(bold(Q))_p) arrow.r "Gal"_(upright(bold(Q)))$.#footnote[Note that we need to fix an embedding $overline(upright(bold(Q))) arrow.r overline(upright(bold(Q))_p)$ to do so.]

In number theory, local objects are simpler than global objects. In the local situation taking modulo reduction makes further simplification. Let us see how this happens for Tate modules of elliptic curve.

Let $E$ be an elliptic curve over a local field $K$, say $upright(bold(Q))_p$. Assume that $E$ has a good reduction, i.e., there is an elliptic curve $E_(upright(bold(Z))_p)$ over $"Spec" (upright(bold(Z))_p)$ whose generic fiber is isomorphic to $E$. Let $E_(upright(bold(F))_p)$ be its special fiber. We want to compare two Tate modules $T_ell (E)$ and $T_ell (E_(upright(bold(F))_p))$. To do so, we need a specialization map.

$ "sp" : T_ell (E) arrow.r T_ell (E_(upright(bold(F))_p)) . $ In fact, we construct a map $ "sp" : G (overline(upright(bold(Q))_p)) arrow.r G_(upright(bold(F))_p) (overline(upright(bold(F))_p)) $ for each $G = E_(upright(bold(Z))_p) [ell^n]$. Since $G_(upright(bold(Z))_p)$ is proper, by the valuative criterion of properness, we obtain $ G (overline(upright(bold(Q))_p)) = G_(upright(bold(Z))_p) (overline(upright(bold(Z))_p)) . $ We compose this with the reduction map $ G_(upright(bold(Z))_p) (overline(upright(bold(Z))_p)) arrow.r G_(upright(bold(F))_p) (overline(upright(bold(F))_p)) $ to obtain the specialization map. One can show that it is a homomorphism and Galois equivariant with respect to the reduction map $"Gal"_(upright(bold(Q))_p) arrow.r "Gal"_(upright(bold(F))_p)$.

If $ell perp p$, then $G = E_(upright(bold(Z))_p) [ell^n]$ is finite étale by the following lemma.

#lemma()[
The kernel $E_(upright(bold(Z))_p) [ell^n]$ is a finite étale group scheme over $"Spec" (upright(bold(Z))_p)$ for all $n$.

] <lem-fin-etale>
In this case, the reduction map becomes a bijection by the following theorem.

#theorem("Stacks Project, #link("https://stacks.math.columbia.edu/tag/09ZS")[Tag 09ZS];")[
For a Henselian local ring $R$ with residue field $k$, the reduction defines equivalence of categories $ upright(F é t) (R) arrow.r upright(F é t) (k) ; quad T arrow.r.bar T_k $

] <thm-fet-henselian>
Indeed, we obtain \$\$ G\_{\\mathbf{Z}\_{p}}(\\overline{\\mathbf{Z}\_{p}}) = \\varinjlim\_{K\'/K} \\operatorname{Hom}\_{\\mathbf{Z}\_{p}}(\\operatorname{Spec}(\\mathscr{O}\_{K\'}), G\_{\\mathbf{Z}\_{p}}) = \\varinjlim\_{K\'/K} \\operatorname{Hom}\_{\\mathbf{F}\_{p}}(\\operatorname{Spec}(k\_{K\'}), G\_{\\mathbf{F}\_{p}}) = G\_{\\mathbf{F}\_{p}}(\\overline{\\mathbf{F}\_{p}}). \$\$

Therefore, we obtain a Galois equivariant isomorphism of $upright(bold(Z))_ell$-modules $ "sp" : T_ell (E) arrow.r T_ell (E_(upright(bold(F))_p)) . $ In particular, the Tate module $T_ell (E)$ is unramified if it has a good reduction and $ell perp p$. In fact, the unramifiedness of Tate module is equivalent to the elliptic curve $E$ has a good reduction!

#theorem("Néron-Ogg-Shafarevich")[
Let $A$ be an abelian variety over a local field $K$ with residual characteristic $p$. The following are equivalent.

+ $A$ has a good reduction.
+ For any $ell perp p$, the $ell$-adic rational Tate module $V_ell (A)$ is unramified.
+ For some $ell perp p$, the $ell$-adic rational Tate module $V_ell (A)$ is unramified.

] <thm-nos>
The natural question is asking what can we say if $ell = p$. For this case, the Tate module $T_ell (E)$ and $T_ell (E_(upright(bold(F))_p))$ are #emph[never] isomorphic! Indeed, while the rank of $T_ell (E)$ is $2$, the rank of $T_ell (E_(upright(bold(F))_p))$ is at most $1$ as $ E_(upright(bold(F))_p) [p^n] tilde.equiv 0 \, upright(bold(Z)) \/ p^n upright(bold(Z)) . $

Still, there is an answer to this question.

#theorem("Grothendieck")[
An abelian variety $A$ over a local field $K$ has a good reduction if and only if $V_p (A)$ is #emph[crystalline];.

] <thm-grothendieck-cris>
We will roughly explain about crystalline representations in the following sections.

#strong[Spoiler.]

- As its name suggests, we will use crystalline cohomology in place of étale cohomology.
- The p-adic counterpart of Tate module is #emph[p-divisible group];. As there is a contravariant relationship between Tate modules and étale cohomology, there is a similar correspondence between p-divisible groups and crystalline cohomology.

= Geometric perspective
<geometric-perspective>
In the previous section, we explained the arithmetic part of p-adic Hodge theory. Still, the question that why it is named with "p-adic Hodge" remains. This section would give an answer.

== Hodge-Tate comparison
<hodge-tate-comparison>
The classical Hodge decomposition is as follows.

#theorem("Hodge decomposition")[
Let $X$ be a smooth proper scheme over $upright(bold(C))$. There is a functorial#footnote[The grading on the right-hand side is functorial as well. \[^convolution grading\]: For two graded vector spaces $V$ and $W$, the convolution grading on $V times.circle W$ is given by $(V times.circle W)^n = xor.big_(i + j = n) V^i times.circle W^j$. \[^convolution filtration\]: For two filtered vector spaces $V$ and $W$, the convolution filtration on $V times.circle W$ is given by $upright(F i l)^n (V times.circle W) colon.eq sum_(i + j = n) V^i times.circle W^j$.] isomorphism of $upright(bold(C))$-vector spaces $ H_(upright("Betti"))^n (X \, upright(bold(Z))) times.circle_(upright(bold(Z))) upright(bold(C)) tilde.equiv xor.big_(i + j = n) H^(i \, j) (X) . $ Here, $H^(i \, j) (X) = H^i (X \, Omega_(X \/ upright(bold(C)))^j)$ and there is the Hodge symmetry $overline(H^(i \, j)) = H^(j \, i)$. In the other words, $H_(upright("Betti"))^n (X \, upright(bold(Z)))$ admits a natural $upright(bold(Z))$-Hodge structure of weight $n$.

] <thm-hodge-decomp>
Tate suggested and Faltings proved a $p$-adic version of this Hodge decomposition. Of course, the replacement of Betti cohomology is étale cohomology. To state this in the full generality, we introduce the notion, #emph[p-adic fields];.

#definition("$p$-adic field")[
A #emph[$p$-adic field] is a characteristic $0$ complete discretely valued field with perfect residue field of characteristic $p$.

] <def-p-adic-field>
#block[
#emph[Remark];. Any $p$-adic field contains $upright(bold(Q))_p$, the topological closure of $upright(bold(Q))$.

]
#example("$p$-adic fields")[
~

+ Finite extensions of $upright(bold(Q))_p$ are $p$-adic fields.
+ The completed maximal unramified field $breve(K) colon.eq hat(K^(upright(u n r)))$ of a finite extension $K \/ upright(bold(Q))_p$ is a $p$-adic field.
+ For any $p$-adic field $K$ with residue field $k$, it contains the "maximal unramified subextension" $K_0 colon.eq W (k) [1 / p]$. This field $K_0$ is a $p$-adic field.
+ The completed algebraic closure $upright(bold(C))_K colon.eq hat(overline(K))$ of a $p$-adic field $K \/ upright(bold(Q))_p$ is #emph[not] a $p$-adic field. Its valuation group is $upright(bold(Q))$.

] <exm-p-adic-fields>
#proposition()[
The completed algebraic closure $upright(bold(C))_K$ of $K$ is algebraically closed.

] <prp-ck-alg-closed>
#theorem("Faltings, Hodge-Tate decomposition")[
Let $X$ be a smooth proper scheme over a $p$-adic field $K$. There is a functorial isomorphism $ H_(upright(é t))^n (X_(overline(K)) \, upright(bold(Q))_p) times.circle_(upright(bold(Q))_p) upright(bold(C))_K tilde.equiv xor.big_(i + j = n) H^i (X \, Omega_(X \/ K)^j) times.circle_K upright(bold(C))_K (- j) . $

] <thm-faltings-ht>
Here, $upright(bold(C))_K (- j)$ is the $(- j)$th #emph[Tate twist] of $upright(bold(C))_K$. Let us define it.

#definition("Tate module $upright(bold(Z))_p (1)$")[
The Tate module $upright(bold(Z))_p (1)$ is defined as follows: \$\$ \\mathbf{Z}\_{p}(1) \\coloneqq T\_{p}(\\mathbf{G}\_{m}) \\coloneqq \\varprojlim\_{n} \\mathbf{G}\_{m}\[p^{n}\](\\overline{K}) = \\varprojlim\_{n} \\mu\_{p^{n}}(\\overline{K}). \$\$ The corresponding character $chi : "Gal"_K arrow.r upright(bold(Z))_p^times$ is called the #emph[$p$-adic cyclotomic character];.

] <def-tate-module>
#definition("Tate twist")[
For a $p$-adic $"Gal"_K$-module $M$, its $n$th Tate twist $M (n)$ is $ M (n) colon.eq cases(delim: "{", M times.circle_(upright(bold(Z))_p) upright(bold(Z))_p (1)^(times.circle n) & n gt.eq 0, "Hom" (upright(bold(Z))_p (n) \, M) & n < 0 .) $

] <def-tate-twist>
Also note that $upright(bold(C))_K$ has a natural $"Gal"_K$-action; an element $sigma in "Gal"_K$ acts on $upright(bold(C))_K$ by completing the continuous map $sigma : overline(K) arrow.r overline(K)$.

The Hodge-Tate decomposition can be written in a fancy way using #emph[Hodge-Tate period ring];.

#definition("Hodge-Tate period ring")[
The #emph[Hodge-Tate period ring] $B_(upright(H T))$ is a ($upright(bold(Z))$-)graded $K$-algebra $ B_(upright(H T)) colon.eq xor.big_(j in upright(bold(Z))) upright(bold(C))_K (j) . $

] <def-bht>
#theorem("Hodge-Tate decomposition, period ring version")[
For any smooth proper $X$ over a $p$-adic field $K$, there is a grading respecting functorial isomorphism $ H_(upright(é t))^n (X_(overline(K)) \, upright(bold(Q))_p) times.circle_(upright(bold(Q))_p) B_(upright(H T)) tilde.equiv (xor.big_(i + j = n) H^i (X \, Omega_(X \/ K)^j)) times.circle_K B_(upright(H T)) . $

] <thm-ht-period>
#block[
#emph[Remark];. 

- The grading on the left-hand side is comes from the grading of $B_(upright(H T))$. The grading on the right-hand side is the convolution grading.\[^convolution grading\]
- Taking $"gr"^0$ to the period ring Hodge-Tate decomposition gives the previous Hodge-Tate decomposition.

]
There is a very important theorem describing the Galois invariant part of $B_(upright(H T))$.

#theorem("Tate-Sen")[
For an integer $j$, $ upright(bold(C))_K (j)^("Gal"_K) = cases(delim: "{", K & j = 0, 0 & j eq.not 0 .) $

] <thm-tate-sen>
This implies $B_(upright(H T))^("Gal"_K) = K$. Hence, if we take the Galois invariant to the Hodge-Tate decomposition, we obtain a grading respecting isomorphism $ (H_(upright(é t))^n (X_(overline(K)) \, upright(bold(Q))_p) times.circle_(upright(bold(Q))_p) B_(upright(H T)))^("Gal"_K) tilde.equiv xor.big_(i + j = n) H^i (X \, Omega_(X \/ K)^j) . $ That means, #emph[étale cohomology remembers Hodge cohomology];.

== de Rham comparison
<de-rham-comparison>
The Hodge-Tate decomposition is not so strong so we cannot obtain many useful properties from this. We need a stronger comparison theorem, and the next step is the #emph[de Rham comparison];. Let us first recall the classical theory.

For a smooth proper scheme $X$ over $upright(bold(C))$, the de Rham cohomology $H_(upright(d R))^n (X \/ upright(bold(C)))$ admits a natural decreasing filtration, called a #emph[Hodge filtration];: $ H_(upright(d R))^n (X \/ upright(bold(C))) = upright(F i l)^0 (H_(upright(d R))^n (X \/ upright(bold(C)))) supset.eq upright(F i l)^1 (H_(upright(d R))^n (X \/ upright(bold(C)))) supset.eq dots.h.c supset.eq upright(F i l)^(n + 1) (H_(upright(d R))^n (X \/ upright(bold(C)))) = 0 . $ The de Rham comparison theorem is $ H_(upright("Betti"))^n (X \, upright(bold(Z))) times.circle_(upright(bold(Z))) upright(bold(C)) tilde.equiv H_(upright(d R))^n (X \/ upright(bold(C))) . $ This recovers the Hodge decomposition via $ H^(i \, j) = upright(F i l)^j (H_(upright(d R))^n (X \/ upright(bold(C)))) sect overline(upright(F i l)^i (H_(upright(d R))^n (X \/ upright(bold(C))))) . $ Although this is equivalent to the Hodge decomposition, in the $p$-adic case, it gives a stronger comparison.

#theorem("Faltings, de Rham comparison")[
There is a filtered $K$-algebra $B_(upright(d R))$ such that, for a smooth proper scheme $X$ over a $p$-adic field $K$, there is a natural filtration respecting isomorphism $ H_(upright(é t))^n (X_(overline(K)) \, upright(bold(Q))_p) times.circle_(upright(bold(Q))_p) B_(upright(d R)) tilde.equiv H_(upright(d R))^n (X \/ K) times.circle_K B_(upright(d R)) . $

] <thm-faltings-dr>
#block[
#emph[Remark];. The filtration on the left-hand side comes from the grading of $B_(upright(d R))$ (as there is no filtration on étale cohomology). On the right-hand side, we give the convolution filtration.\[^convolution filtration\]

]
We are not going to define $B_(upright(d R))$, but let us list the main properties of $B_(upright(d R))$.

#proposition("Properties of $B_(upright(d R))$")[
The de Rham period ring $B_(upright(d R))$ is a filtered $K$-algebra with a continuous $"Gal"_K$-action such that

- $"gr" (upright(F i l)^bullet (B_(upright(d R)))) = B_(upright(H T))$,
- $B_(upright(d R))^("Gal"_K) = K$.

] <prp-bdr>
By the first property, we can recover the Hodge-Tate comparison from de Rham comparison by taking the associated graded vector space. By the second property, we can recover the de Rham cohomology from étale cohomology.

== Crystalline comparison theorem
<crystalline-comparison-theorem>
The last comparison theorem is the #emph[crystalline comparison];.

#theorem("Faltings, crystalline comparison")[
Let $K$ be a $p$-adic field with (perfect) residue field $k$ and $K_0 colon.eq W (k) [1 / p]$ be the maximal unramified subextension. There is a $"Gal"_K$-stable $K_0$-subalgebra $B_(upright(c r i s))$ of $B_(upright(d R))$ such that, for a proper smooth $X$ over $K$ with a good reduction $X_(W (k))$, we obtain a natural Galois and $phi$ equivariant filtration respecting isomorphism $ H_(upright(é t))^n (X_(overline(K)) \, upright(bold(Q))_p) times.circle_(upright(bold(Q))_p) B_(upright(c r i s)) tilde.equiv H_(upright(c r i s))^n (X_k \/ W (k)) [1 / p] times.circle_(K_0) B_(upright(c r i s)) $ recovering the de Rham comparison after tensoring $B_(upright(d R))$.

] <thm-faltings-cris>
Again, we are not going to define the period ring $B_(upright(c r i s))$. Instead, we list some properties of it.

#proposition("Properties of $B_(upright(c r i s))$")[
$B_(upright(c r i s))$ is a $"Gal"_K$-stable $K_0$-subalgebra of $B_(upright(d R))$ with the induced filtration. Additionally, it is equipped with a $phi$-action whose restriction to $K_0$ is the Witt vector Frobenius of $K_0$. Also, $B_(upright(c r i s))^("Gal"_K) = K_0$.

] <prp-bcris>
By the last property, we obtain this.

#corollary()[
$(H_(upright(é t))^n (X_(overline(K)) \, upright(bold(Q))_p) times.circle_(upright(bold(Q))_p) B_(upright(c r i s)))^("Gal"_K) tilde.equiv H_(upright(c r i s))^n (X_k \/ W (k)) [1 / p]$.

] <cor-cris-invariant>
#block[
#emph[Remark];. This can be thought of as "crystalline cohomology is the right $p$-adic replacement of étale cohomology". Compare this with the proper-smooth base change theorem for étale cohomology.

]
#theorem("proper-smooth base change, Milne Theorem 20.4")[
Let $R$ be a Henselian local domain with fraction field $K$ and residue field $k$. For any $X$ proper smooth scheme over $R$, there is a natural map called a (co)specialization $ "sp" : H_(upright(é t))^n (X_k \, upright(bold(Q))_ell) arrow.r H_(upright(é t))^n (X_K \, upright(bold(Q))_ell) $ which is a Galois equivariant isomorphism.

] <thm-proper-smooth>
#exercise()[
Prove the (co)specialization map is Galois equivariant with respect to the reduction map $"Gal"_K arrow.r "Gal"_k$. In particular, $H_(upright(é t))^n (X_(overline(K)) \, upright(bold(Q))_ell)$ is unramified if $X$ has a good reduction.

] <exr-cosp-galois>
= Period rings and functors
<period-rings-and-functors>
In this section, we will make a formal setup to express what we explained in a categorical language. Throughout this section, we fix a p-adic field $K$ and let $B in { B_(upright(H T)) \, B_(upright(d R)) \, B_(upright(c r i s)) }$.

#definition("Functor $D_B$")[
We define a functor $D_B : upright(R e p)_(upright(bold(Q))_p) ("Gal"_K) arrow.r upright(V e c t)_B^(\*)$ as $ D_B (V) colon.eq (V times.circle_(upright(bold(Q))_p) B)^Gamma . $ Here, $upright(V e c t)_B^(\*)$ is the category of $B^("Gal"_K)$-vector spaces with additional structure, where the additional structure is given as follows.

- If $B = B_(upright(H T))$, the additional structure is the grading.
- If $B = B_(upright(d R))$, the additional structure is the filtration.
- If $B = B_(upright(c r i s))$, the additional structure is the filtration with $phi$-action.

] <def-db-functor>
#definition("$B$-admissible representation")[
We say a representation $V in upright(R e p)_(upright(bold(Q))_p) ("Gal"_K)$ is #emph[$B$-admissible] if the natural map $ alpha_V : D_B (V) times.circle_(B^("Gal"_K)) B arrow.r V times.circle_(upright(bold(Q))_p) (B times.circle_(B^("Gal"_K)) B) arrow.r V times.circle_(upright(bold(Q))_p) B $ is an isomorphism. We denote by $upright(R e p)_(upright(bold(Q))_p)^B ("Gal"_K)$ the full subcategory of $upright(R e p)_(upright(bold(Q))_p) ("Gal"_K)$ consisting of $B$-admissible representations.

] <def-b-admissible>
#example("$B_(upright(H T))$-admissibility")[
Let $B = B_(H T)$. Then, the map $ alpha_V : D_(upright(H T)) (V) times.circle_K B_(upright(H T)) arrow.r V times.circle_(upright(bold(Q))_p) B_(upright(H T)) $ is an isomorphism if and only if the $"gr"^0$-part $ "gr"^0 (alpha_V) : xor.big_(j in upright(bold(Z))) (V times.circle_(upright(bold(Q))_p) upright(bold(C))_K (j))^("Gal"_K) times.circle upright(bold(C))_K (- j) arrow.r V times.circle_(upright(bold(Q))_p) upright(bold(C))_K $ is an isomorphism as the $"gr"^j$-part is the $j$th Tate twist of $"gr"^0$-part.

] <exm-ht-admissible>
#lemma("Serre-Tate")[
The map $"gr"^0 (alpha_V)$ is injective.

] <lem-serre-tate>
#corollary()[
$dim_(K_0) (D_(upright(c r i s)) (V)) lt.eq dim_K (D_(upright(d R)) (V)) lt.eq dim_K (D_(upright(H T)) (V)) lt.eq dim_(upright(bold(Q))_p) (V)$.

] <cor-dim-ineq>
#block[
#emph[Proof];. The last inequality follows from Serre-Tate. To prove the first inequality, we need one fact.

#strong[Fact.] The natural map $B_(upright(c r i s)) times.circle_(K_0) K arrow.r B_(upright(d R))$ is injective.

Thus, the natural map $ V times.circle_(upright(bold(Q))_p) (B_(upright(c r i s)) times.circle_(K_0) K) arrow.r V times.circle_(upright(bold(Q))_p) B_(upright(d R)) $ is injective, and the $"Gal"_K$-invariant $ (V times.circle_(upright(bold(Q))_p) (B_(upright(c r i s)) times.circle_(K_0) K))^("Gal"_K) arrow.r (V times.circle_(upright(bold(Q))_p) B_(upright(d R)))^("Gal"_K) $ is injective as well. The source is $D_(upright(c r i s)) (V) times.circle_(K_0) K$ and the target is $D_(upright(d R)) (V)$. Hence, we obtain $dim_(K_0) (D_(upright(c r i s)) (V)) lt.eq dim_K (D_(upright(d R)) (V))$.

The middle inequality follows as $ dim_K (D_(upright(d R)) (V)) = dim_K ("gr"^bullet (D_(upright(d R)) (V))) lt.eq dim_K (("gr"^bullet (V times.circle_(upright(bold(Q))_p) B_(upright(d R))))^("Gal"_K)) = dim_K (D_(upright(H T)) (V)) $ by the left-exactness of $"Gal"_K$-invariant.

]
#block[
#emph[Remark];. In fact, $alpha_V$ and $"gr"^0 (alpha_V)$ being an isomorphism only depends on $V times.circle_(upright(bold(Q))_p) upright(bold(C))_K$. Furthermore, $ D_(upright(H T)) : upright(R e p)_(upright(bold(C))_K) ("Gal"_K) arrow.r upright(V e c t)_K^("Gr") $ is an equivalence of categories with a quasi-inverse $D arrow.r.bar "gr"^0 (D times.circle_K B_(upright(H T)))$ (\[Brinon-Conrad, Theorem 2.4.11\]).

]
In fact, there is a more general result.

#theorem()[
The natural map $alpha_V$ is injective. In particular, the map $alpha_V$ is an isomorphism if and only if $dim_(B^("Gal"_K)) (D_B (V)) = dim_(upright(bold(Q))_p) (V)$.

] <thm-alpha-inj>
#corollary()[
$upright(R e p)_(upright(bold(Q))_p)^(B_(upright(c r i s))) ("Gal"_K) subset upright(R e p)_(upright(bold(Q))_p)^(B_(upright(d R))) ("Gal"_K) subset upright(R e p)_(upright(bold(Q))_p)^(B_(upright(H T))) ("Gal"_K)$

] <cor-admissible-inclusion>
#block[
#emph[Proof];. If $V$ is $B_(upright(c r i s))$-admissible, then $ dim_(upright(bold(Q))_p) (V) = dim_K (D_(upright(c r i s)) (V)) lt.eq dim_K (D_(upright(d R)) (V)) lt.eq dim_(upright(bold(Q))_p) (V) . $ Hence, $V$ is $B_(upright(d R))$-admissible. Similarly, $B_(upright(d R))$-admissibility implies $B_(upright(H T))$-admissibility.

]


 
  
#set bibliography(style: "../../../american-mathematical-society-label.csl") 


#bibliography("../../../references.bib")

